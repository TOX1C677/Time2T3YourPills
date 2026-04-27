package com.example.time2t3yourpills;

        import android.app.Notification;
        import android.app.NotificationChannel;
        import android.app.NotificationManager;
        import android.app.PendingIntent;
        import android.content.BroadcastReceiver;
        import android.content.Context;
        import android.content.Intent;
        import android.os.Build;

        import androidx.core.app.NotificationCompat;

public class NotificationHelper {

    private static final String CHANNEL_ID = "medication_reminder_channel";
    private static final String CHANNEL_NAME = "Medication Reminder";
    private static final String CHANNEL_DESCRIPTION = "Reminders for medication intake";
    private final Context context;

    public NotificationHelper(Context context) {
        this.context = context;
        createNotificationChannel();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription(CHANNEL_DESCRIPTION);

            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
    }

    public Notification buildNotification(String title, String message) {
        Intent confirmIntent = new Intent(context, ConfirmReceiver.class);
        PendingIntent confirmPendingIntent = PendingIntent.getBroadcast(context, 0, confirmIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        NotificationCompat.Action confirmAction = new NotificationCompat.Action.Builder(
                R.drawable.ic_confirm,
                context.getString(R.string.confirm),
                confirmPendingIntent
        ).build();

        return new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(message)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .addAction(confirmAction)
                .build();
    }

}
