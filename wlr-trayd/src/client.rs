//! wlr-tray — tiny client for wlr-trayd's unix socket.

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;

fn main() -> std::io::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() {
        eprintln!("usage: wlr-tray <list|activate|secondary|menu|menu-click> [args...]");
        std::process::exit(1);
    }
    let runtime = std::env::var("XDG_RUNTIME_DIR")
        .unwrap_or_else(|_| "/tmp".to_string());
    let path = format!("{runtime}/wlr-trayd.sock");

    let mut stream = match UnixStream::connect(&path) {
        Ok(s) => s,
        Err(_) => return Ok(()), // daemon not running, exit quietly
    };

    let cmd = format!("{}\n", args.join(" "));
    stream.write_all(cmd.as_bytes())?;
    stream.shutdown(std::net::Shutdown::Write)?;

    let mut buf = [0u8; 4096];
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    loop {
        let n = stream.read(&mut buf)?;
        if n == 0 { break; }
        out.write_all(&buf[..n])?;
    }
    Ok(())
}
