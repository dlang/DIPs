import metadata;

version (unittest) { } else
void main ( string[] args )
{
    import std.string;

    string dipFolder;

    if (args.length == 1)
        dipFolder = "./DIPs";
    else
        dipFolder = args[1 .. $].join();

    import std.format;

    import std.path, std.file, std.utf;

    DIPMetadata[] DIPs;

    foreach (entry; dirEntries(dipFolder, "DIP*.md", SpanMode.shallow))
    {
        auto contents = cast(string) read(entry.name);
        validate(contents);
        DIPs ~= DIPMetadata.fromAA(parseFirstMdTable(contents));
    }

    import std.algorithm : sort;

    static bool sortPredicate ( DIPMetadata a, DIPMetadata b )
    {
        if (a.status == b.status)
            return a.id < b.id;
        else
            return a.status < b.status;
    }

    sort!sortPredicate(DIPs);
    writeSummary(DIPs, buildNormalizedPath(dipFolder, "README.md"));
}

/**
    Extracts metadata from DIP markdown sources.

    Looks for markdown resembling table lines and parses first table
    column as key and second as value.

    Params:
        source = markdown source to parse

    Returns:
       Associative array storing key-value mapping from found table lines
 */
string[string] parseFirstMdTable ( string source )
{
    import std.regex;
    import std.string : strip;

    typeof(return) result;

    static title = regex(r"^# (.+)$", "mg");
    auto title_match = source.matchFirst(title);
    if (!title_match.empty)
        result["Title"] = strip(title_match[1]);

    static lines = regex(r"^\|\s*(\w+):\s*\|(.+)\|$", "mg");

    foreach (match; source.matchAll(lines))
        result[match[1]] = strip(match[2]);

    return result;
}

unittest
{
    string input =
`
# Volatile read/write intrinsics
| Section        | Value |
|----------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| DIP:           | 20                                                                                                                                             |
| Status:        | Implemented                                                                                                                                    |
| Links:         | [proposed implementation](https://issues.dlang.org/show_bug.cgi?id=13138), [pull](https://github.com/D-Programming-Language/druntime/pull/892) |
`;

    auto metadata = parseFirstMdTable(input);
    assert(metadata["Title"] == "Volatile read/write intrinsics");
    assert(metadata["DIP"] == "20");
    assert(metadata["Status"] == "Implemented");
}

/**
 */
void writeSummary ( DIPMetadata[] DIPs, string fileName )
{
    import std.uni : byGrapheme;
    import std.range : walkLength;
    import std.conv, std.format;

    static struct ColumnWidths
    {
        size_t id, title, status;
    }

    ColumnWidths widths;

    void updateMax ( ref size_t max_width, string next )
    {
        auto next_width = next.byGrapheme.walkLength;
        if (next_width > max_width)
            max_width = next_width;
    }

    foreach (dip; DIPs)
    {
        updateMax(widths.id, format("[%s](./DIP%1$s.md)", dip.id));
        updateMax(widths.title, dip.title);
        updateMax(widths.status, to!string(dip.status));
    }

    import std.stdio;
    import std.range : repeat;

    auto output = File(fileName, "w");

    auto lineFormat = format("|%%%ss|%%%ss|%%%ss|",
        widths.id, widths.title, widths.status);

    output.writefln(lineFormat, "ID", "Title", "Status");
    output.writefln(
        lineFormat,
        '-'.repeat(widths.id),
        '-'.repeat(widths.title),
        '-'.repeat(widths.status)
    );

    foreach (dip; DIPs)
        output.writefln(lineFormat, format("[%1$s](./DIP%1$s.md)", dip.id),
            dip.title, dip.status);
}
