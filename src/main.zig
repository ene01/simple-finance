const std = @import("std");

const Transaction = struct {
    amount: f64,
    year: usize,
    month: u8,
    day: u8,
    exch_type: u8,
    category: []const u8,
    note: []const u8,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    const page_alloc = std.heap.page_allocator;
    var list_counter: usize = 0;

    try stdout.print("=== What name should the file have? (using an existing name will overwrite that file!):\n", .{});

    var filename_buf: [128]u8 = undefined;
    const filename = try stdin.readUntilDelimiterOrEof(&filename_buf, '\n');
    const filename_trimmed = std.mem.trimRight(u8, filename.?, "\r\n");
    const filename_ext = try std.fmt.allocPrint(page_alloc, "{s}.csv", .{filename_trimmed});
    defer page_alloc.free(filename_ext);

    const file = try std.fs.cwd().createFile(filename_ext, .{ .read = true });
    defer file.close();

    try stdout.print("=== What's your budget? (Money you currently have or expected after calculations): ", .{});
    var budget_buffer: [32]u8 = undefined;
    const budget_string = try stdin.readUntilDelimiterOrEof(&budget_buffer, '\n');
    const budget_trimmed = std.mem.trimRight(u8, budget_string.?, "\r\n");
    const budget: f64 = try std.fmt.parseFloat(f64, budget_trimmed);

    var money_left: f64 = budget;

    const first_csv_line = try std.fmt.allocPrint(page_alloc, ",Budget: ${d},,,\n", .{budget});
    defer page_alloc.free(first_csv_line);

    try file.writeAll(first_csv_line);

    try stdout.print("=== Let's begin adding entries!\n", .{});

    while (true) {
        var current_trans = Transaction{ .amount = undefined, .year = undefined, .month = undefined, .day = undefined, .exch_type = undefined, .category = undefined, .note = undefined };
        var amount_buffer: [64]u8 = undefined;
        var year_buffer: [8]u8 = undefined;
        var month_buffer: [4]u8 = undefined;
        var day_buffer: [4]u8 = undefined;
        var exch_type_buffer: [16]u8 = undefined;
        var category_buffer: [64]u8 = undefined;
        var note_buffer: [128]u8 = undefined;

        var exch_parsed: []const u8 = undefined;
        var csv_line: []u8 = undefined;

        if (list_counter > 0) {
            const no_string = try std.fmt.allocPrint(page_alloc, "n", .{});

            try stdout.print("=== Add a new entry? (y/n): ", .{});

            var buffer: [4]u8 = undefined;
            const string = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
            const trimmed = std.mem.trimRight(u8, string.?, "\r\n");

            if (std.mem.eql(u8, trimmed, no_string)) {
                break;
            }
        }

        try stdout.print("= Amount: ", .{});
        const amount_string = try stdin.readUntilDelimiterOrEof(&amount_buffer, '\n');
        const amount_trimmed = std.mem.trimRight(u8, amount_string.?, "\r\n");
        current_trans.amount = try std.fmt.parseFloat(f64, amount_trimmed);

        try stdout.print("= Year: ", .{});
        const year_string = try stdin.readUntilDelimiterOrEof(&year_buffer, '\n');
        const year_trimmed = std.mem.trimRight(u8, year_string.?, "\r\n");
        current_trans.year = try std.fmt.parseInt(usize, year_trimmed, 10);

        try stdout.print("= Month: ", .{});
        const month_string = try stdin.readUntilDelimiterOrEof(&month_buffer, '\n');
        const month_trimmed = std.mem.trimRight(u8, month_string.?, "\r\n");
        current_trans.month = try std.fmt.parseInt(u8, month_trimmed, 10);

        if (current_trans.month > 12) {
            current_trans.month = 12;
        } else if (current_trans.month == 0) {
            current_trans.month = 1;
        }

        if (isLeapYear(current_trans.year) and current_trans.month == 2) {
            try stdout.print("= Day (February has 29 days!): ", .{});
        } else {
            try stdout.print("= Day: ", .{});
        }

        const day_string = try stdin.readUntilDelimiterOrEof(&day_buffer, '\n');
        const day_trimmed = std.mem.trimRight(u8, day_string.?, "\r\n");
        current_trans.day = try std.fmt.parseInt(u8, day_trimmed, 10);

        if (current_trans.day > 31) {
            current_trans.day = 31;
        } else if (current_trans.day == 0) {
            current_trans.day = 1;
        }

        try stdout.print("= Type (1-Income 2-Expense): ", .{});
        const exch_type_string = try stdin.readUntilDelimiterOrEof(&exch_type_buffer, '\n');
        const exch_type_trimmed = std.mem.trimRight(u8, exch_type_string.?, "\r\n");
        current_trans.exch_type = try std.fmt.parseInt(u8, exch_type_trimmed, 10);

        if (current_trans.exch_type >= 2) {
            money_left -= current_trans.amount;
            current_trans.exch_type = 2;
            exch_parsed = try std.fmt.allocPrint(page_alloc, "Expense", .{});
        } else if (current_trans.exch_type <= 1) {
            money_left += current_trans.amount;
            current_trans.exch_type = 1;
            exch_parsed = try std.fmt.allocPrint(page_alloc, "Income", .{});
        }
        defer page_alloc.free(exch_parsed);

        try stdout.print("= Category: ", .{});
        const category_string = try stdin.readUntilDelimiterOrEof(&category_buffer, '\n');
        const category_trimmed = std.mem.trimRight(u8, category_string.?, "\r\n");
        current_trans.category = category_trimmed;

        try stdout.print("= Extra note: ", .{});
        const note_string = try stdin.readUntilDelimiterOrEof(&note_buffer, '\n');
        const note_trimmed = std.mem.trimRight(u8, note_string.?, "\r\n");
        current_trans.note = note_trimmed;

        csv_line = try std.fmt.allocPrint(page_alloc, "{d}/{d}/{d},${d},{s},{s},{s}\n", .{ current_trans.year, current_trans.month, current_trans.day, current_trans.amount, exch_parsed, current_trans.category, current_trans.note });
        defer page_alloc.free(csv_line);

        try file.writeAll(csv_line);

        list_counter += 1;
    }

    const last_csv_line = try std.fmt.allocPrint(page_alloc, ",Total: ${d},,,\n", .{money_left});
    defer page_alloc.free(last_csv_line);

    try file.writeAll(last_csv_line);

    try stdout.print("=== Done, file was saved as '{s}.csv', bye bye.", .{filename_trimmed});
}

/// Determines if the year is a leap year.
fn isLeapYear(year: usize) bool {
    return (year % 4 == 0) and ((year % 100 != 0) or (year % 400 == 0));
}
