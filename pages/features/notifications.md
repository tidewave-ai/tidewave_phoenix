# Notifications

Tidewave supports browser notifications for when the agent completes its work or requires your input.

## Usage

To enable them, go to "Settings" by clicking on the cog icon on the top right of your chat application. Under "General", you will find a "Background Notifications" toggle. Clicking it will enable notifications (your browser will likely ask you for permissions).

To test that they are working, you can ask Tidewave to "sleep for 2 seconds" and then promptly switch to another tab or minimize the application. You should see a notification like below shortly after:

![Notification example](assets/notification.png)

## Troubleshooting

Tidewave may fail to emit notifications for different reasons.

**Browser restrictions:** Some browsers, like Safari, allow disabling websites from asking for notification permissions altogether. If you have enabled such restrictions, turning notifications on will fail and you will see an error message within Tidewave.

**Operating system settings:** Even if you enable notifications in the browser, your operating system may have disabled them altogether. This usually means you can enable notifications in Tidewave but you won't see them (they will silently fail). In such cases, make sure that:

* your browser of choice is allowed to send notifications in your Operating System settings
* your computer is not on "focus mode" or similar, which will disable notifications