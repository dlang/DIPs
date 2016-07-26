module metadata;

enum Status
{
    Rejected,
    Draft,
    Approved,
    Implemented
}

struct DIPMetadata
{
    size_t id;
    string title;
    Status status;

    string author;

    static DIPMetadata fromAA ( string[string] kv )
    {
        import std.conv;

        DIPMetadata metadata;
        metadata.id = to!size_t(kv["DIP"]);
        metadata.title = kv["Title"];
        metadata.author = kv["Author"];
        metadata.status = to!Status(kv["Status"]);
        return metadata;
    }
}
