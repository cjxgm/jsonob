
import json, jsonob, options

type
    Result = object
        status: Status
        messages: seq[Message]
        error: Option[string]       # exists only when status == failed

    Status = enum
        ok
        failed

    Message = object
        `from`: Option[string]    # none for "anonymous"
        text: string
        date: Date

    Date = tuple
        year: int
        month: int
        day: int


proc test(s: string) =
    let r = s.parse_json.to Result

    case r.status
    of Status.ok:
        for message in r.messages:
            echo message.`from`
            echo message.text
            echo message.date
    of Status.failed:
        echo "failed"
        echo r.error.get()

    echo()

test """
{
    "status": "ok",
    "messages": [
        {
            "text": "hello world",
            "date": [2016, 7, 15]
        }
    ]
}
"""

test """
{
    "status": "failed",
    "messages": [],
    "error": "that's an error"
}
"""

