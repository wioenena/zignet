const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var args: std.process.ArgIterator = undefined;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (comptime builtin.target.os.tag == .windows) {
        args = try std.process.argsWithAllocator(allocator);
    } else {
        args = std.process.args();
    }

    _ = args.next(); // skip the first argument (the program name)
    const addr_str = args.next();
    const port_str = args.next();

    if (addr_str == null or port_str == null) {
        std.debug.print("Usage: nc <address> <port>\n", .{});
        return;
    }

    const port = try std.fmt.parseInt(u16, port_str.?, 10);
    const addr = try std.net.Address.parseIp4(addr_str.?, port);

    const stream = try std.net.tcpConnectToAddress(addr);
    defer stream.close();

    std.debug.print("Connected to {s}:{d}\n", .{ addr_str.?, port });
    defer std.debug.print("Connection closed\n", .{});

    handleConnection(stream, allocator) catch |err| {
        if (err == std.net.Stream.ReadError.ConnectionResetByPeer or err == std.net.Stream.WriteError.ConnectionResetByPeer) {
            return;
        }

        return err;
    };
}

fn handleConnection(stream: std.net.Stream, allocator: std.mem.Allocator) !void {
    const writer = stream.writer();
    const reader = stream.reader();
    const stdinReader = std.io.getStdIn().reader();
    const stdoutWriter = std.io.getStdOut().writer();
    while (true) {
        _ = try stdoutWriter.write("> ");
        const line = try stdinReader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        if (line.len == 0) {
            break;
        }
        try writer.writeAll(line);
        const response = try reader.readUntilDelimiterAlloc(allocator, '\r', std.math.maxInt(usize));
        if (response.len == 0) {
            break;
        }

        _ = try stdoutWriter.write("Recevied: ");
        try stdoutWriter.writeAll(response);
        try stdoutWriter.writeAll("\n");
    }
}
