package com.example.time2t3yourpills;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Binder;
import android.os.CountDownTimer;
import android.os.IBinder;
import android.util.Log;

import androidx.lifecycle.Observer;  // Добавлено
import androidx.lifecycle.ViewModelProvider;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import com.example.time2t3yourpills.models.Medication;
import com.example.time2t3yourpills.repository.MedicationRepository;

import java.util.List;

public class TimerService extends Service {

    public static final String ACTION_TIMER_UPDATE = "com.example.time2t3yourpills.ACTION_TIMER_UPDATE";
    public static final String EXTRA_TIMER_VALUE = "com.example.time2t3yourpills.EXTRA_TIMER_VALUE";
    public static final String ACTION_CONFIRM = "com.example.time2t3yourpills.ACTION_CONFIRM";
    public static final String ACTION_SNOOZE = "com.example.time2t3yourpills.ACTION_SNOOZE";

    private final IBinder binder = new TimerBinder();
    private CountDownTimer timer;
    private NotificationHelper notificationHelper;
    private MedicationViewModel medicationViewModel;
    private long duration;
    private int repeatCount;
    private long lastDuration;
    private int lastRepeatCount;

    private MedicationRepository medicationRepository; // Ваш репозиторий

    @Override
    public void onCreate() {
        super.onCreate();
        medicationRepository = new MedicationRepository(getApplication());
        Log.d("TimerService", "onCreate called");
        new AsyncTask<Void, Void, Medication>() {
            @Override
            protected Medication doInBackground(Void... voids) {
                return medicationRepository.getMedicationByIdSync("YOUR_MEDICATION_ID");
            }

            @Override
            protected void onPostExecute(Medication medication) {
                if (medication != null) {
                    duration = medication.getTimer() * 60 * 1000;
                    repeatCount = medication.getRepetitions();
                }
            }
        }.execute();
        notificationHelper = new NotificationHelper(this);
    }

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d("TimerService", "onStartCommand called");
        if (intent != null) {
            String action = intent.getAction();
            if (ACTION_CONFIRM.equals(action)) {
                onConfirmationReceived();
            } else if ("SET_TIMER_VALUE".equals(action)) {
                duration = intent.getLongExtra("TIMER_VALUE", 0);
            }
        }
        updateTimerSettings("YOUR_MEDICATION_ID"); // Добавлено для примера, здесь должен быть реальный ID
        return START_STICKY;
    }

    public void updateTimerSettings(String medicationId) {
        new Thread(() -> {
            Medication medication = medicationRepository.getMedicationByIdSync(medicationId);
            if (medication != null) {
                duration = medication.getTimer() * 60 * 1000;
                repeatCount = medication.getRepetitions();
            }
        }).start();
    }


    public class TimerBinder extends Binder {
        TimerService getService() {
            return TimerService.this;
        }
    }

    public void startTimerFromService() { // Изменено
        this.lastDuration = duration;
        this.lastRepeatCount = repeatCount;

        if (timer != null) {
            timer.cancel();
        }

        timer = new CountDownTimer(duration, 1000) {
            @Override
            public void onTick(long millisUntilFinished) {
                sendTimerUpdate(millisUntilFinished, true);
            }

            @Override
            public void onFinish() {
                sendTimerUpdate(0, false);
                sendNotification();

                if (repeatCount > 0) {
                    repeatCount--;
                    startTimerFromService();
                }
            }
        };
        timer.start();
    }

    public void onConfirmationReceived() {
        if (timer != null) {
            timer.cancel();
        }
        NotificationManager notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        notificationManager.cancel(1);

        startTimerFromService();
    }

    private void sendTimerUpdate(long millisUntilFinished, boolean isRunning) {
        Intent intent = new Intent(ACTION_TIMER_UPDATE);
        intent.putExtra(EXTRA_TIMER_VALUE, millisUntilFinished);
        intent.putExtra("is_running", isRunning);
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
    }

    private void sendNotification() {
        if (notificationHelper != null) {
            String title = "Medication Reminder";
            String message = "It's time to take your medication.";
            Notification notification = notificationHelper.buildNotification(title, message);
            NotificationManager notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            notificationManager.notify(1, notification);
        }
    }
}
