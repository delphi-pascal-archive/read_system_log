//
// Reading the Event Log
//
// The ReadEventLog function reads event records from an event log.
// It returns a buffer containing an EVENTLOGRECORD structure that
// describes a logged event. The following example reads all the
// records in the Application log and displays the event identifier,
// event type, and event source for each event log entry.
//
#include <windows.h>
#include <stdio.h>

#define BUFFER_SIZE 1024*64

//void DisplayEntries( )
void main(void)
{
    HANDLE h;
    EVENTLOGRECORD *pevlr;
    BYTE bBuffer[BUFFER_SIZE];
    DWORD dwRead, dwNeeded, dwThisRecord;

    // Open the Application event log.

    h = OpenEventLog( NULL,    // use local computer
             "Application");   // source name
    if (h == NULL)
    {
        printf("Could not open the Application event log.");
        return;
    }

    pevlr = (EVENTLOGRECORD *) &bBuffer;

    // Get the record number of the oldest event log record.

    GetOldestEventLogRecord(h, &dwThisRecord);

    // Opening the event log positions the file pointer for this
    // handle at the beginning of the log. Read the event log records
    // sequentially until the last record has been read.

    while (ReadEventLog(h,                // event log handle
                EVENTLOG_FORWARDS_READ |  // reads forward
                EVENTLOG_SEQUENTIAL_READ, // sequential read
                0,            // ignored for sequential reads
                pevlr,        // pointer to buffer
                BUFFER_SIZE,  // size of buffer
                &dwRead,      // number of bytes read
                &dwNeeded))   // bytes in next record
    {
        while (dwRead > 0)
        {
            // Print the record number, event identifier, type,
            // and source name.

            printf("%03d  Event ID: 0x%08X  Event type: ",
                dwThisRecord++, pevlr->EventID);

            switch(pevlr->EventType)
            {
                case EVENTLOG_ERROR_TYPE:
                    printf("EVENTLOG_ERROR_TYPE\t  ");
                    break;
                case EVENTLOG_WARNING_TYPE:
                    printf("EVENTLOG_WARNING_TYPE\t  ");
                    break;
                case EVENTLOG_INFORMATION_TYPE:
                    printf("EVENTLOG_INFORMATION_TYPE  ");
                    break;
                case EVENTLOG_AUDIT_SUCCESS:
                    printf("EVENTLOG_AUDIT_SUCCESS\t  ");
                    break;
                case EVENTLOG_AUDIT_FAILURE:
                    printf("EVENTLOG_AUDIT_FAILURE\t  ");
                    break;
                default:
                    printf("Unknown ");
                    break;
            }

            printf("Event source: %s\n",
                (LPSTR) ((LPBYTE) pevlr + sizeof(EVENTLOGRECORD)));

            dwRead -= pevlr->Length;
            pevlr = (EVENTLOGRECORD *)
                ((LPBYTE) pevlr + pevlr->Length);
        }

        pevlr = (EVENTLOGRECORD *) &bBuffer;
    }

    CloseEventLog(h);
}
