const std = @import("std");
const net = std.net;
const allocator = std.heap;
const Address = net.Address;
pub const Io_mode = .evented;

pub fn main() !void {
    // GPA para detectar leaks nas estruturas do pool
    var gpa = allocator.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_alloc = gpa.allocator();

    // Pool usa GPA (baixo overhead, só init)
    var pool: std.Thread.Pool = undefined;
    // Inicializa o pool com 25 workers (sweet spot)
    try pool.init(.{ .allocator = gpa_alloc, .n_jobs = 25 });
    defer pool.deinit();

    // Servidor TCP na porta 4040
    const address = try Address.parseIp4("127.0.0.1", 4040);
    // Listen com configurações padrão
    var server = try address.listen(.{});
    // Inicializa o servidor
    defer server.deinit();

    std.debug.print("Server listening on 127.0.0.1:4040 (Thread Pool: 25 workers)\n", .{});
    std.debug.print("Pool allocator: GPA (leak detection)\n", .{});
    std.debug.print("Task allocator: page_allocator (max performance)\n", .{});

    while (true) {
        const conn = try server.accept();

        // Tasks usam page_allocator (máxima performance)
        try pool.spawn(handleConnection, .{ conn, std.heap.page_allocator });
    }
}

fn handleConnection(conn: net.Server.Connection, alloc: std.mem.Allocator) void {
    defer conn.stream.close();

    // Arena em cima do page_allocator (máxima performance)
    var arena = allocator.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const mem = arena.allocator();

    // Exemplo: alocar buffer se necessário
    _ = mem; // Usar quando precisar alocar memória

    _ = conn.stream.write("Hello, World!\n") catch |err| {
        std.debug.print("Error writing to client: {}\n", .{err});
        return;
    };

    std.debug.print("Connection handled\n", .{});
}
