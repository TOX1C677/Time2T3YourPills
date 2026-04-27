package com.example.time2t3yourpills;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class SnoozeReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(final Context context, Intent intent) {
        final long snoozeDuration = intent.getLongExtra("snooze_duration", 0);

        Intent serviceIntent = new Intent(context, TimerService.class);
        serviceIntent.setAction(TimerService.ACTION_SNOOZE);
        context.startService(serviceIntent);
    }
}
