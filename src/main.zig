const std = @import("std");

const Transaction = struct { amount: f64, year: usize, month: u8, day: u8, exch_type: u8, category: [64]u8, note: [128]u8, category_size: usize, note_size: usize };

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    const page_alloc = std.heap.page_allocator;

    var entry_counter: usize = 0;
    var filename_buf: [128]u8 = undefined;
    var budget_buffer: [128]u8 = undefined;
    var entries_buffer = std.ArrayList(Transaction).init(page_alloc);
    defer entries_buffer.deinit();
    var money_left: f64 = undefined;

    // TODO: File importing.
    // I should probably add something at the start to verify the .csv is supported
    try stdout.print("=== What name should the file have? (using an existing name will overwrite that file!):\n", .{});
    const filename = try stdin.readUntilDelimiterOrEof(&filename_buf, '\n');
    const filename_trimmed = std.mem.trimRight(u8, filename.?, "\r\n");
    const filename_ext = try std.fmt.allocPrint(page_alloc, "{s}.csv", .{filename_trimmed});

    // Budget setter.
    try stdout.print("=== What's your budget? (Money you currently have or expected after calculations): ", .{});
    const budget_string = try stdin.readUntilDelimiterOrEof(&budget_buffer, '\n');
    const budget_trimmed = std.mem.trimRight(u8, budget_string.?, "\r\n");
    const budget: f64 = try std.fmt.parseFloat(f64, budget_trimmed);
    money_left = budget;

    try stdout.print("=== Let's begin adding entries!\n", .{});

    while (true) {
        var amount: f64 = undefined;
        var year: usize = undefined;
        var month: u8 = undefined;
        var day: u8 = undefined;
        var exch_type: u8 = undefined;
        var category: []const u8 = undefined;
        var category_size: usize = undefined; // Used to save the string limit, to avoid showing trash on the category string.
        var note: []const u8 = undefined;
        var note_size: usize = undefined; // Same as category size.
        var loop_counter: isize = 0;

        if (entry_counter > 0) {
            const no_string = try std.fmt.allocPrint(page_alloc, "n", .{});
            var entry_buffer: [4]u8 = undefined;

            try stdout.print("=== Add a new entry? (y/n): ", .{});

            const entry_string = try stdin.readUntilDelimiterOrEof(&entry_buffer, '\n');
            const entry_trimmed = std.mem.trimRight(u8, entry_string.?, "\r\n");

            if (std.mem.eql(u8, entry_trimmed, no_string)) {
                break;
            }
        }

        while (true) {
            var input_buffer: [64]u8 = undefined;
            var input_string: ?[]u8 = undefined;
            var input_trimmed: []const u8 = undefined;

            switch (loop_counter) {
                0 => {
                    try stdout.print("= Amount: ", .{});
                },
                1 => {
                    try stdout.print("= Year: ", .{});
                },
                2 => {
                    try stdout.print("= Month: ", .{});
                },
                3 => {
                    if (isLeapYear(year) and month == 2) {
                        try stdout.print("= Day (February has 29 days!): ", .{});
                    } else {
                        try stdout.print("= Day: ", .{});
                    }
                },
                4 => {
                    try stdout.print("= Type (1-Income 2-Expense): ", .{});
                },
                5 => {
                    try stdout.print("= Category: ", .{});
                },
                6 => {
                    try stdout.print("= Extra note: ", .{});
                },
                else => {
                    unreachable;
                },
            }

            input_string = try stdin.readUntilDelimiterOrEof(&input_buffer, '\n');
            input_trimmed = std.mem.trimRight(u8, input_string.?, "\r\n");

            switch (loop_counter) {
                0 => {
                    amount = try std.fmt.parseFloat(f64, input_trimmed);
                },
                1 => {
                    year = try std.fmt.parseInt(usize, input_trimmed, 10);
                },
                2 => {
                    const value = try std.fmt.parseInt(u8, input_trimmed, 10);
                    month = if (value > 12) 12 else if (value == 0) 1 else value;
                },
                3 => {
                    const value = try std.fmt.parseInt(u8, input_trimmed, 10);
                    day = if (value > 31) 31 else if (value == 0) 1 else value;
                },
                4 => {
                    const value = try std.fmt.parseInt(u8, input_trimmed, 10);

                    if (value >= 2) {
                        money_left -= amount;
                        exch_type = 2;
                    } else if (value <= 1) {
                        money_left += amount;
                        exch_type = 1;
                    }
                },
                5 => {
                    category = try page_alloc.dupe(u8, input_trimmed);
                    category_size = input_trimmed.len;
                },
                6 => {
                    note = try page_alloc.dupe(u8, input_trimmed);
                    note_size = input_trimmed.len;
                },
                else => unreachable,
            }

            if (loop_counter == 6) break;

            loop_counter += 1;
        }
        var category_converted: [64]u8 = undefined;
        var note_converted: [128]u8 = undefined;

        category_converted[0] = 0;
        note_converted[0] = 0;

        std.mem.copyForwards(u8, &category_converted, category);
        std.mem.copyForwards(u8, &note_converted, note);

        const entry = Transaction{ .amount = amount, .year = year, .month = month, .day = day, .exch_type = exch_type, .category = category_converted, .note = note_converted, .category_size = category_size, .note_size = note_size };
        try entries_buffer.append(entry);
        entry_counter += 1;
    }

    // File creation.
    const file = try std.fs.cwd().createFile(filename_ext, .{ .read = true });
    defer file.close();

    const first_csv_line = try std.fmt.allocPrint(page_alloc, "Budget: ${d},,,,\n", .{budget});
    defer page_alloc.free(first_csv_line);
    try file.writeAll(first_csv_line);

    for (entries_buffer.items) |entry| {
        const line = try std.fmt.allocPrint(page_alloc, "${d},{d}/{d}/{d},{d},{s},{s}\n", .{ entry.amount, entry.day, entry.month, entry.year, entry.exch_type, entry.category[0..entry.category_size], entry.note[0..entry.note_size] });
        defer page_alloc.free(line);
        try file.writeAll(line);
    }

    const last_csv_line = try std.fmt.allocPrint(page_alloc, "Total: ${d},,,,\n", .{money_left});
    defer page_alloc.free(last_csv_line);

    // TODO: Ask the user for sorting type (date, amount, exchange type, category (alphabetically), note (also alphabetically))
    // Remember to skip first and last entry since they have no values and are only for showcase.

    try file.writeAll(last_csv_line);

    try stdout.print("=== Done, file was saved as '{s}.csv', bye bye.", .{filename_trimmed});
}

/// Determines if the year is a leap year.
fn isLeapYear(year: usize) bool {
    return (year % 4 == 0) and ((year % 100 != 0) or (year % 400 == 0));
}
