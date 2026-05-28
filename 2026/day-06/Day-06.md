> ### Creating a file

1. `touch notes.txt` - Creates empy text file name notes.txt

> ### Writing text to a file

2.  `echo "Line 1: Hello, DevOps world!" > notes.txt` - add first line to text file

> ### Appending new lines

3.  `echo "Line 2: Logs, configs, scripts are text files." >> notes.txt`
    echo "Line 3: Logs, configs, scripts are text files." >> notes.txt
    append more lines `>>` append content.

    ![alt text](<Screenshot From 2026-05-28 12-50-09.png> "First Three Commands")

4.  `echo "Line 4: tee writes AND shows output at once." | tee -a notes.txt`
    `tee` writes and shows output at once

> ### Reading the file back

1. `cat notes.txt`

    ![alt text](<Screenshot From 2026-05-28 12-56-39.png>)

2. `head -n 2 notes.txt` - Display first 2 lines in notes.txt file
3. `tail -n 2 notes.txt` - Display last 2 lines in notes.txt file

    ![alt text](<Screenshot From 2026-05-28 14-12-19.png>)
