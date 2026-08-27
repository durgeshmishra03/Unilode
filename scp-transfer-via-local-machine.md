# SCP File Transfer Between Two Servers (Via Local Machine)

## Overview
Use this when you need to move a folder/file from Server A to Server B, but Server A and Server B **can't talk to each other directly**. As long as your local laptop can connect to both servers, you can use it as a middleman to copy the data across.

## Prerequisites / Changes to Make Before Running
- Replace `user` with the actual SSH username for each server.
- Replace `<source-public-ip>` with the actual public IP (or hostname) of the source/destination server.
- Replace `/path/to/folder` with the actual folder/file path — make sure the path is correct on both ends.
- Replace `./folder` with the local path where you want to save/pick up the folder on your laptop.
- Make sure you have SSH access (key or password) to both servers from your laptop.
- Check disk space locally if the folder is large — it gets downloaded to your laptop first.

## Steps
1. **Download** the folder from the source server to your local machine.
2. **Upload** that downloaded folder from your local machine to the destination server.

## Commands & One-Line Explanation

```bash
scp -r user@<source-public-ip>:/path/to/folder ./folder
```
👉 This downloads the folder from the remote server to your laptop.

```bash
scp -r ./folder user@<source-public-ip>:/path/to/folder
```
👉 This uploads that same folder from your laptop to the other server.

## Note
This is a two-hop transfer (Server A → Laptop → Server B). It works fine for small-to-medium sized data. For very large transfers, consider setting up direct connectivity or using `rsync` instead.
