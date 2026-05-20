/*
 * wlr-taskd — small daemon that subscribes to zwlr_foreign_toplevel_manager_v1,
 * assigns stable per-toplevel IDs, and exposes list/focus/minimize over a
 * unix socket. Used by ewwii's taskbar so duplicate app_id+title windows are
 * still individually addressable.
 */
#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <time.h>
#include <wayland-client.h>
#include "wlr-ftm-protocol.h"

#define MAX_TOPLEVELS 256
#define APP_ID_MAX 128
#define TITLE_MAX  256
#define BCAST_SLOTS 32
#define BCAST_TITLE_DISP 18    /* full title up to here; longer truncates to 14 + ".." */
#define BCAST_TITLE_TRUNC 14
/* Toplevels younger than this are hidden from list/broadcast. Short-lived
 * overlays like flameshot's screen capture create+destroy a toplevel in well
 * under a second; debouncing them keeps the taskbar from growing/shrinking
 * (and ewwii's layer surface from drifting taller) for transients. */
#define TASKBAR_DEBOUNCE_MS 1500

typedef struct {
    int     in_use;
    int     id;
    int     activated;
    int     minimized;
    long    first_seen_ms;     /* monotonic; for new-toplevel debounce */
    char    app_id[APP_ID_MAX];
    char    title[TITLE_MAX];
    struct  zwlr_foreign_toplevel_handle_v1 *handle;
} Toplevel;

static Toplevel tops[MAX_TOPLEVELS];
static int next_id = 1;
static struct zwlr_foreign_toplevel_manager_v1 *manager = NULL;
static struct wl_seat *seat = NULL;

/* Forward declarations — debounce helpers are defined further down with the
 * slot management code but are used by build_current_snap below. */
static int  toplevel_visible(const Toplevel *t);
static long next_warmup_expiry_ms(void);
static long now_ms(void);

/* --- broadcast: push state directly into ewwii's GlobalVars on change ----- */

typedef struct {
    int  id;
    int  exists;
    char title[TITLE_MAX];     /* display-truncated */
    char focused[24];          /* "tb-item" | "tb-item tb-focused" | "tb-item tb-minimized" */
    char app_id[APP_ID_MAX];
    char icon[512];            /* resolved file path or empty */
} SlotSnap;

static SlotSnap prev_snap[BCAST_SLOTS];
static int snap_initialized = 0;
/* During the initial wl_display_roundtrip we receive on_mgr_toplevel events
 * for every existing window. Those are NOT new — flip this on after the
 * roundtrip so subsequent additions are the only ones that get debounced. */
static int post_init_seed = 0;
/* Rate limit: at most one broadcast per BROADCAST_MIN_INTERVAL_MS, regardless
 * of how rapidly events arrive. Apps with spinner titles fire continuously,
 * so a pure debounce ("wait for quiet period") never settles. */
static int  broadcast_pending     = 0;
static long broadcast_due_ms      = 0;
static long last_broadcast_ms     = 0;
#define BROADCAST_MIN_INTERVAL_MS 100

static const char *focused_class_for(const Toplevel *t) {
    if (t->activated) return "tb-item tb-focused";
    if (t->minimized) return "tb-item tb-minimized";
    return "tb-item";
}

static int title_cmp(const void *a, const void *b) {
    const Toplevel *ta = *(const Toplevel * const *)a;
    const Toplevel *tb = *(const Toplevel * const *)b;
    int c = strcmp(ta->title, tb->title);
    if (c != 0) return c;
    return ta->id - tb->id;
}

/* Decode a UTF-8 codepoint at *bytes*, returning its byte-length (1–4) or 1
 * for malformed continuation. Does not validate the continuation bytes
 * strictly — just enough to advance the cursor on a codepoint boundary. */
static size_t utf8_step(const unsigned char *p) {
    if ((p[0] & 0x80) == 0x00) return 1;
    if ((p[0] & 0xE0) == 0xC0) return 2;
    if ((p[0] & 0xF0) == 0xE0) return 3;
    if ((p[0] & 0xF8) == 0xF0) return 4;
    return 1;  /* malformed lead byte */
}

static void display_title(const char *src, char *dst, size_t dst_sz) {
    /* Codepoint-aware truncation: > BCAST_TITLE_DISP codepoints → first
     * BCAST_TITLE_TRUNC codepoints + "..".  Byte-based truncation produced
     * invalid UTF-8 mid-codepoint, which broke ewwii's argv parser. */
    const unsigned char *p = (const unsigned char *)src;
    size_t cp_count = 0, pos = 0, src_len = strlen(src);
    while (pos < src_len) {
        size_t step = utf8_step(p + pos);
        if (pos + step > src_len) break;
        pos += step;
        cp_count++;
    }

    if (cp_count > (size_t)BCAST_TITLE_DISP) {
        size_t cp_seen = 0, cut = 0;
        while (cut < src_len && cp_seen < (size_t)BCAST_TITLE_TRUNC) {
            size_t step = utf8_step(p + cut);
            if (cut + step > src_len) break;
            cut += step;
            cp_seen++;
        }
        if (cut + 3 >= dst_sz) cut = dst_sz - 4;
        memcpy(dst, src, cut);
        dst[cut]   = '.';
        dst[cut+1] = '.';
        dst[cut+2] = 0;
    } else {
        strncpy(dst, src, dst_sz - 1);
        dst[dst_sz - 1] = 0;
    }
}

/* Resolve app_id → icon path by shelling out to the existing app_icon script.
 * Cheap because that script has its own /tmp cache. Returns "" if not found. */
static void resolve_icon(const char *app_id, char *out, size_t out_sz) {
    out[0] = 0;
    if (!app_id || !*app_id) return;
    const char *home = getenv("HOME");
    if (!home) home = "";
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "%s/.config/ewwii/scripts/app_icon %s 2>/dev/null", home, app_id);
    FILE *fp = popen(cmd, "r");
    if (!fp) return;
    if (fgets(out, (int)out_sz, fp)) {
        size_t l = strlen(out);
        while (l > 0 && (out[l-1] == '\n' || out[l-1] == '\r')) out[--l] = 0;
    }
    pclose(fp);
}

static void build_current_snap(SlotSnap out[BCAST_SLOTS]) {
    const Toplevel *sorted[MAX_TOPLEVELS];
    int n = 0;
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        if (tops[i].in_use && toplevel_visible(&tops[i])) sorted[n++] = &tops[i];
    }
    qsort(sorted, (size_t)n, sizeof(sorted[0]), title_cmp);

    for (int i = 0; i < BCAST_SLOTS; i++) {
        if (i < n) {
            const Toplevel *t = sorted[i];
            out[i].id     = t->id;
            out[i].exists = 1;
            display_title(t->title, out[i].title, sizeof(out[i].title));
            strncpy(out[i].app_id,  t->app_id,  sizeof(out[i].app_id) - 1);
            out[i].app_id[sizeof(out[i].app_id) - 1] = 0;
            strncpy(out[i].focused, focused_class_for(t), sizeof(out[i].focused) - 1);
            out[i].focused[sizeof(out[i].focused) - 1] = 0;

            /* Resolve icon only when app_id changes — avoid spawning app_icon
             * on every broadcast for slots whose window didn't move. */
            if (strcmp(out[i].app_id, prev_snap[i].app_id) == 0 && prev_snap[i].icon[0]) {
                strncpy(out[i].icon, prev_snap[i].icon, sizeof(out[i].icon) - 1);
                out[i].icon[sizeof(out[i].icon) - 1] = 0;
            } else {
                resolve_icon(out[i].app_id, out[i].icon, sizeof(out[i].icon));
            }
        } else {
            out[i].id      = 0;
            out[i].exists  = 0;
            out[i].title[0]   = 0;
            out[i].app_id[0]  = 0;
            out[i].icon[0]    = 0;
            strncpy(out[i].focused, "tb-item", sizeof(out[i].focused) - 1);
            out[i].focused[sizeof(out[i].focused) - 1] = 0;
        }
    }
}

static long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

/* Schedule a broadcast to fire no sooner than BROADCAST_MIN_INTERVAL_MS after
 * the previous one. Repeated events don't push the deadline back. */
static void schedule_broadcast(void) {
    if (broadcast_pending) return;   /* already scheduled, don't push it out */
    broadcast_pending = 1;
    long earliest = last_broadcast_ms + BROADCAST_MIN_INTERVAL_MS;
    long now = now_ms();
    broadcast_due_ms = earliest > now ? earliest : now;
}

/* Append `name="escaped"` to dst, growing buf if needed. */
static void append_mapping(char **dst, size_t *cap, size_t *len, const char *name, const char *val) {
    /* worst-case size: name + '="' + 2*len(val) for escaping + '" ' + null */
    size_t needed = *len + strlen(name) + 4 + 2 * strlen(val) + 2;
    if (needed > *cap) {
        size_t newcap = *cap ? *cap : 256;
        while (newcap < needed) newcap *= 2;
        char *n = realloc(*dst, newcap);
        if (!n) return;
        *dst = n;
        *cap = newcap;
    }
    if (*len > 0) (*dst)[(*len)++] = ',';
    /* name */
    size_t nlen = strlen(name);
    memcpy(*dst + *len, name, nlen);
    *len += nlen;
    (*dst)[(*len)++] = '=';
    (*dst)[(*len)++] = '"';
    /* value with backslash-escape for " and \ */
    for (const char *p = val; *p; p++) {
        if (*p == '"' || *p == '\\') (*dst)[(*len)++] = '\\';
        (*dst)[(*len)++] = *p;
    }
    (*dst)[(*len)++] = '"';
    (*dst)[*len] = 0;
}

static void broadcast_slots(void) {
    SlotSnap cur[BCAST_SLOTS];
    build_current_snap(cur);

    int force = !snap_initialized;

    char  *mappings = NULL;
    size_t cap = 0, mlen = 0;
    int    changes = 0;

#define PUSH_STR(name, val) do { append_mapping(&mappings, &cap, &mlen, name, val); changes++; } while (0)

    for (int i = 0; i < BCAST_SLOTS; i++) {
        int n = i + 1;
        char keybuf[64];
        char valbuf[TITLE_MAX + 4];
        /* A slot can be REASSIGNED to a different window when sort order shifts
         * (e.g. a spinner-title rotation moves a window past its neighbor).
         * When the slot's id changes, all its fields belong to a new window —
         * push every field, not just the ones that happen to differ. */
        int slot_replaced = (cur[i].id != prev_snap[i].id);
        int resync = force || slot_replaced;

        if (resync || cur[i].id != prev_snap[i].id) {
            snprintf(keybuf, sizeof(keybuf), "win_%d_id", n);
            snprintf(valbuf, sizeof(valbuf), "%d", cur[i].id);
            PUSH_STR(keybuf, valbuf);
        }
        if (resync || cur[i].exists != prev_snap[i].exists) {
            snprintf(keybuf, sizeof(keybuf), "win_%d_exists", n);
            PUSH_STR(keybuf, cur[i].exists ? "true" : "false");
        }
        if (resync || strcmp(cur[i].title, prev_snap[i].title)) {
            snprintf(keybuf, sizeof(keybuf), "win_%d_title", n);
            PUSH_STR(keybuf, cur[i].title);
        }
        if (resync || strcmp(cur[i].focused, prev_snap[i].focused)) {
            snprintf(keybuf, sizeof(keybuf), "win_%d_focused", n);
            PUSH_STR(keybuf, cur[i].focused);
        }
        if (resync || strcmp(cur[i].icon, prev_snap[i].icon)) {
            snprintf(keybuf, sizeof(keybuf), "win_%d_icon", n);
            PUSH_STR(keybuf, cur[i].icon);
        }
    }
#undef PUSH_STR

    if (changes > 0 && mappings) {
        pid_t pid = fork();
        if (pid == 0) {
            int devnull = open("/dev/null", O_RDWR);
            if (devnull >= 0) {
                dup2(devnull, 0); dup2(devnull, 1); dup2(devnull, 2);
                if (devnull > 2) close(devnull);
            }
            char *argv[] = { "ewwii", "update", mappings, NULL };
            execvp("ewwii", argv);
            _exit(127);
        }
        /* parent doesn't wait — SIGCHLD ignored, kernel reaps */
    }
    free(mappings);

    memcpy(prev_snap, cur, sizeof(prev_snap));
    snap_initialized = 1;
}

static Toplevel *slot_by_id(int id) {
    for (int i = 0; i < MAX_TOPLEVELS; i++)
        if (tops[i].in_use && tops[i].id == id) return &tops[i];
    return NULL;
}

static Toplevel *slot_by_handle(struct zwlr_foreign_toplevel_handle_v1 *h) {
    for (int i = 0; i < MAX_TOPLEVELS; i++)
        if (tops[i].in_use && tops[i].handle == h) return &tops[i];
    return NULL;
}

static Toplevel *new_slot(struct zwlr_foreign_toplevel_handle_v1 *h) {
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        if (!tops[i].in_use) {
            tops[i].in_use = 1;
            tops[i].id = next_id++;
            tops[i].activated = 0;
            tops[i].minimized = 0;
            /* Existing windows seen during initial roundtrip aren't transients;
             * pin first_seen_ms to 0 so toplevel_visible() returns true now. */
            tops[i].first_seen_ms = post_init_seed ? now_ms() : 0;
            tops[i].handle = h;
            tops[i].app_id[0] = 0;
            tops[i].title[0] = 0;
            return &tops[i];
        }
    }
    return NULL;
}

/* A toplevel is "visible" to ewwii / clients only after it's been around for
 * TASKBAR_DEBOUNCE_MS. Filters out transient flameshot-style overlays. */
static int toplevel_visible(const Toplevel *t) {
    return (now_ms() - t->first_seen_ms) >= TASKBAR_DEBOUNCE_MS;
}

/* Earliest moment a currently-warming toplevel will become visible.
 * Used as a poll() wakeup so the bar refreshes promptly after debounce. */
static long next_warmup_expiry_ms(void) {
    long earliest = -1;
    long now = now_ms();
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        if (!tops[i].in_use) continue;
        long expiry = tops[i].first_seen_ms + TASKBAR_DEBOUNCE_MS;
        if (expiry > now && (earliest < 0 || expiry < earliest)) earliest = expiry;
    }
    return earliest;
}

static void release_slot(Toplevel *t) {
    t->in_use = 0;
    t->handle = NULL;
}

/* --- toplevel handle events ---------------------------------------------- */

static void on_title(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, const char *title) {
    Toplevel *t = slot_by_handle(h);
    if (!t) return;
    strncpy(t->title, title ? title : "", TITLE_MAX - 1);
    t->title[TITLE_MAX - 1] = 0;
}

static void on_app_id(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, const char *app_id) {
    Toplevel *t = slot_by_handle(h);
    if (!t) return;
    strncpy(t->app_id, app_id ? app_id : "", APP_ID_MAX - 1);
    t->app_id[APP_ID_MAX - 1] = 0;
}

static void on_state(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, struct wl_array *array) {
    Toplevel *t = slot_by_handle(h);
    if (!t) return;
    t->activated = 0;
    t->minimized = 0;
    uint32_t *p;
    wl_array_for_each(p, array) {
        if (*p == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED) t->activated = 1;
        if (*p == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED) t->minimized = 1;
    }
    /* Single-focus invariant: at most one window should be activated. If this
     * one just became activated, clear activated on all others. Defends against
     * compositors that fire the activate event for the new window without a
     * matching deactivate for the old one. */
    if (t->activated) {
        for (int i = 0; i < MAX_TOPLEVELS; i++) {
            if (tops[i].in_use && &tops[i] != t) tops[i].activated = 0;
        }
    }
}

static void on_closed(void *d, struct zwlr_foreign_toplevel_handle_v1 *h) {
    Toplevel *t = slot_by_handle(h);
    if (!t) return;
    zwlr_foreign_toplevel_handle_v1_destroy(h);
    release_slot(t);
    schedule_broadcast();
}

/* The `done` event marks the end of an atomic batch of property updates for a
 * given toplevel. Broadcast once per batch to coalesce title+app_id+state into
 * a single ewwii update call. */
static void on_done(void *d, struct zwlr_foreign_toplevel_handle_v1 *h) {
    schedule_broadcast();
}
static void on_parent(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, struct zwlr_foreign_toplevel_handle_v1 *p) {}
static void on_output_enter(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, struct wl_output *o) {}
static void on_output_leave(void *d, struct zwlr_foreign_toplevel_handle_v1 *h, struct wl_output *o) {}

static const struct zwlr_foreign_toplevel_handle_v1_listener handle_listener = {
    .title          = on_title,
    .app_id         = on_app_id,
    .output_enter   = on_output_enter,
    .output_leave   = on_output_leave,
    .state          = on_state,
    .done           = on_done,
    .closed         = on_closed,
    .parent         = on_parent,
};

/* --- manager events ------------------------------------------------------ */

static void on_mgr_toplevel(void *d, struct zwlr_foreign_toplevel_manager_v1 *m,
                            struct zwlr_foreign_toplevel_handle_v1 *h) {
    if (new_slot(h))
        zwlr_foreign_toplevel_handle_v1_add_listener(h, &handle_listener, NULL);
    /* The initial property events fire right after, so on_done will broadcast.
     * For removals we also need a broadcast — see on_closed re-entry below. */
}

static void on_mgr_finished(void *d, struct zwlr_foreign_toplevel_manager_v1 *m) {}

static const struct zwlr_foreign_toplevel_manager_v1_listener mgr_listener = {
    .toplevel = on_mgr_toplevel,
    .finished = on_mgr_finished,
};

/* --- registry events ----------------------------------------------------- */

static void on_global(void *d, struct wl_registry *r, uint32_t name,
                      const char *iface, uint32_t version) {
    if (!strcmp(iface, zwlr_foreign_toplevel_manager_v1_interface.name)) {
        uint32_t v = version > 3 ? 3 : version;
        manager = wl_registry_bind(r, name, &zwlr_foreign_toplevel_manager_v1_interface, v);
        zwlr_foreign_toplevel_manager_v1_add_listener(manager, &mgr_listener, NULL);
    } else if (!strcmp(iface, wl_seat_interface.name)) {
        uint32_t v = version > 7 ? 7 : version;
        seat = wl_registry_bind(r, name, &wl_seat_interface, v);
    }
}

static void on_global_remove(void *d, struct wl_registry *r, uint32_t name) {}

static const struct wl_registry_listener registry_listener = {
    .global = on_global,
    .global_remove = on_global_remove,
};

/* --- socket command handling --------------------------------------------- */

static void writeall(int fd, const char *buf, size_t n) {
    while (n) {
        ssize_t w = write(fd, buf, n);
        if (w <= 0) return;
        buf += w;
        n   -= (size_t)w;
    }
}

static void cmd_list(int fd) {
    /* Same alphabetical sort + debounce filter as broadcast_slots so ewwii's
     * cache lines line up with the slot positions the daemon pushes via
     * `ewwii update`. Transients (e.g. flameshot's 1s overlay) are excluded. */
    const Toplevel *sorted[MAX_TOPLEVELS];
    int n = 0;
    for (int i = 0; i < MAX_TOPLEVELS; i++) {
        if (tops[i].in_use && toplevel_visible(&tops[i])) sorted[n++] = &tops[i];
    }
    qsort(sorted, (size_t)n, sizeof(sorted[0]), title_cmp);

    char buf[1024];
    for (int i = 0; i < n; i++) {
        const Toplevel *t = sorted[i];
        const char *state = t->activated ? "F" : (t->minimized ? "M" : "N");
        int w = snprintf(buf, sizeof(buf), "%d\t%s\t%s\t%s\n",
                         t->id, t->app_id, t->title, state);
        if (w > 0) writeall(fd, buf, (size_t)w);
    }
}

static void cmd_focus(int id) {
    Toplevel *t = slot_by_id(id);
    if (t && seat) zwlr_foreign_toplevel_handle_v1_activate(t->handle, seat);
}
static void cmd_minimize(int id) {
    Toplevel *t = slot_by_id(id);
    if (t) zwlr_foreign_toplevel_handle_v1_set_minimized(t->handle);
}
static void cmd_unminimize(int id) {
    Toplevel *t = slot_by_id(id);
    if (t) zwlr_foreign_toplevel_handle_v1_unset_minimized(t->handle);
}
static void cmd_close(int id) {
    Toplevel *t = slot_by_id(id);
    if (t) zwlr_foreign_toplevel_handle_v1_close(t->handle);
}

static void handle_client(int client_fd) {
    char buf[1024];
    ssize_t r = read(client_fd, buf, sizeof(buf) - 1);
    if (r <= 0) return;
    buf[r] = 0;
    char *nl = strchr(buf, '\n');
    if (nl) *nl = 0;

    char cmd[32], arg[32];
    int parts = sscanf(buf, "%31s %31s", cmd, arg);
    if (parts < 1) return;
    if (!strcmp(cmd, "list")) {
        cmd_list(client_fd);
    } else if (parts == 2) {
        int id = atoi(arg);
        if      (!strcmp(cmd, "focus"))      cmd_focus(id);
        else if (!strcmp(cmd, "minimize"))   cmd_minimize(id);
        else if (!strcmp(cmd, "unminimize")) cmd_unminimize(id);
        else if (!strcmp(cmd, "close"))      cmd_close(id);
    }
}

/* --- main ---------------------------------------------------------------- */

int main(void) {
    /* Reap broadcast children automatically — we don't wait() on them. */
    signal(SIGCHLD, SIG_IGN);

    struct wl_display *display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "wlr-taskd: wl_display_connect failed\n"); return 1; }

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);   /* deliver globals */
    if (!manager) { fprintf(stderr, "wlr-taskd: compositor has no zwlr_foreign_toplevel_manager_v1\n"); return 1; }
    if (!seat)    { fprintf(stderr, "wlr-taskd: compositor has no wl_seat\n"); return 1; }
    wl_display_roundtrip(display);   /* deliver initial toplevels */
    post_init_seed = 1;              /* anything new after this point is debounced */

    char sockpath[256];
    snprintf(sockpath, sizeof(sockpath), "/run/user/%d/wlr-taskd.sock", getuid());
    unlink(sockpath);

    int listen_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (listen_fd < 0) { perror("socket"); return 1; }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sockpath, sizeof(addr.sun_path) - 1);

    if (bind(listen_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) { perror("bind"); return 1; }
    if (listen(listen_fd, 8) < 0) { perror("listen"); return 1; }
    chmod(sockpath, 0600);

    int wl_fd = wl_display_get_fd(display);
    struct pollfd pfds[2] = {
        { .fd = wl_fd,     .events = POLLIN },
        { .fd = listen_fd, .events = POLLIN },
    };

    fprintf(stderr, "wlr-taskd: listening on %s\n", sockpath);

    /* Seed an initial broadcast so ewwii catches up at startup. */
    schedule_broadcast();

    while (1) {
        wl_display_flush(display);
        /* If a broadcast is pending, wait at most until it's due.
         * Also wake up when any warming toplevel matures so we re-broadcast. */
        int timeout_ms = -1;
        long now = now_ms();
        if (broadcast_pending) {
            long delta = broadcast_due_ms - now;
            timeout_ms = delta > 0 ? (int)delta : 0;
        }
        long warmup_expiry = next_warmup_expiry_ms();
        if (warmup_expiry > 0) {
            long until = warmup_expiry - now;
            if (until < 0) until = 0;
            if (timeout_ms < 0 || until < (long)timeout_ms) timeout_ms = (int)until;
        }
        int n = poll(pfds, 2, timeout_ms);
        if (n < 0) {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        }
        /* Fire deferred broadcast if its deadline elapsed. */
        if (broadcast_pending && now_ms() >= broadcast_due_ms) {
            broadcast_pending = 0;
            broadcast_slots();
            last_broadcast_ms = now_ms();
        }
        /* A warmup expiry may have fired with no other event — schedule a
         * broadcast so newly-matured toplevels get pushed to ewwii. */
        if (warmup_expiry > 0 && now_ms() >= warmup_expiry) {
            schedule_broadcast();
        }
        if (pfds[0].revents & POLLIN) {
            if (wl_display_dispatch(display) < 0) {
                fprintf(stderr, "wlr-taskd: wayland dispatch error\n");
                break;
            }
        }
        if (pfds[1].revents & POLLIN) {
            int client_fd = accept(listen_fd, NULL, NULL);
            if (client_fd < 0) continue;
            handle_client(client_fd);
            wl_display_flush(display);
            close(client_fd);
        }
    }

    unlink(sockpath);
    return 0;
}
