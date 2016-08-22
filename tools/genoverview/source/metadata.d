module metadata;

struct Status
{
    enum StatusEnum
    {
        Rejected,
        Draft,
        Approved,
        PendingImplementation,
        Implemented
    }

    StatusEnum value;
    alias value this;

    string toString ( )
    {
        static import std.conv;

        if (value == Status.PendingImplementation)
            return "Pending Implementation";
        else
            return std.conv.to!string(value);
    }

    static auto fromString ( string status )
    {
        static import std.conv;

        if (status == "Pending Implementation")
            return Status.PendingImplementation;
        else
            return std.conv.to!StatusEnum(status);
    }
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
        metadata.status = Status.fromString(kv["Status"]);
        return metadata;
    }
}
