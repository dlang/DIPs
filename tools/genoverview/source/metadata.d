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
    string url;

    static DIPMetadata fromAA ( string[string] kv, string urlBase )
    {
        import std.conv, std.format;

        DIPMetadata metadata;
        metadata.id = to!size_t(kv["DIP"]);
        metadata.title = kv["Title"];
        metadata.author = kv["Author"];
        metadata.url = format(
            "%s/DIP%s.md", urlBase,  metadata.id);
        metadata.status = to!Status(kv["Status"]);
        return metadata;
    }
}
