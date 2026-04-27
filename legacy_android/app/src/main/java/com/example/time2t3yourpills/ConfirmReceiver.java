package com.example.time2t3yourpills;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class ConfirmReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(final Context context, Intent intent) {
        Intent serviceIntent = new Intent(context, TimerService.class);
        serviceIntent.setAction(TimerService.ACTION_CONFIRM);
        context.startService(serviceIntent);
    }
}
