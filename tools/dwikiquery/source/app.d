import std.format : format;
import std.exception : enforce;

enum CommandVerbs
{
    /// Attempts to load DIP source, convert it to markdown and write
    /// result to disk in a current folder. Example:
    /// dwikiquery fetch --id 42
    fetch
}

void main(string[] args)
{
    {
        import std.process;
        enforce(
            executeShell("pandoc -v").status == 0,
            "pandoc (http://pandoc.org) must be on PATH"
        );
    }

    ulong id;

    import std.getopt;
    
    auto optinfo = getopt(
        args,
        "id", "DIP number", &id
    );

    string verb = args[1];

    import std.conv : to;

    final switch (to!CommandVerbs(verb))
    {
        case CommandVerbs.fetch:
            enforce(id > 0, "Must specify DIP id to fetch");
            string source = preProcess(getDIPfromWiki(id));
            toMarkdownFile(source, id); 
        break;
    }
}

/**
    Fetches DIP source text using Mediawiki API

    Params:
        ID of a DIP such that wiki.dlang.org/DIP<ID> page contains
        current text of the DIP.

    Returns:
        Text of DIP wiki page in Mediawiki format
 */
string getDIPfromWiki(ulong id)
{
    import vibe.data.json;    
    import vibe.http.client;

    string api_url = format(
        "https://wiki.dlang.org/api.php?format=json&action=query&prop=revisions&rvprop=content&titles=DIP%s",
        id
    );

    string wikitext;

    requestHTTP(
        api_url,
        (scope req) { },
        (scope res) {
            auto json = res.readJson();
            json = json["query"]["pages"];
            // object key may vary but there will always be exactly one:
            enforce(json.length == 1);
            foreach (page; json)
            {
                enforce(page["revisions"].length == 1);
                wikitext = page["revisions"][0]["*"].get!string();
            }
        }
    );

    return wikitext;
}

/**
    Does some pre-processing of downloaded mediwiki sources to
    prepare those for pandoc conversion.

    Params:
        original downloaded mediawiki source

    Returns:
        same source adjusted for better conversion results
 */
string preProcess ( string source )
{
    import std.regex;
    import std.algorithm;
    import std.range;

    // remove category link
    static rgx_category = regex(r"\[Category: DIP\]", "s");

    source = source
        .splitter('\n')
        .filter!(line => !line.matchFirst(rgx_category))
        .join('\n');

    return source;
}

/**
    Does some post-processing on converted sources to make resulting markdown
    Github-compatible

    Params:
        converted = pandoc conversion output

    Returns:
        final markdown source
 */
string postProcess ( string converted )
{
    import std.regex;
    import std.algorithm;
    import std.range;

    /// fix code blocks
    static rgx_codeblock = regex(r"``` \{\.d\}", "si");

    converted = converted
        .splitter('\n')
        .map!(line => line.replaceAll(rgx_codeblock, "```d"))
        .join('\n');

    return converted;
}

/**
    Converts mediawiki source to markdown (using pandoc shell call) and writes
    resulting text to a file in current folder named "DIP<ID>.md".

    Params:
        wikitext = Mediawiki formatted DIP source text
        id = DIP number
 */
void toMarkdownFile(string wikitext, ulong id)
{
    import std.process;

    auto pandoc = pipeShell(
        format("pandoc -t markdown_github -f mediawiki -o DIP%s.md", id)
    );
    pandoc.stdin.write(wikitext);
    pandoc.stdin.flush();
    pandoc.stdin.close();
    wait(pandoc.pid);
}
