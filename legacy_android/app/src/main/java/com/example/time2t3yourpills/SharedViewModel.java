package com.example.time2t3yourpills;

import android.app.Application;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

public class SharedViewModel extends AndroidViewModel {
    private final MutableLiveData<Long> timerValue = new MutableLiveData<>();
    private final MutableLiveData<Integer> repeatCount = new MutableLiveData<>();
    private BroadcastReceiver receiver;

    public SharedViewModel(Application application) {
        super(application);

        IntentFilter filter = new IntentFilter();
        filter.addAction(TimerService.ACTION_TIMER_UPDATE);

        receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                long value = intent.getLongExtra(TimerService.EXTRA_TIMER_VALUE, 0);
                timerValue.setValue(value);
            }
        };

        LocalBroadcastManager.getInstance(application).registerReceiver(receiver, filter);
    }

    @Override
    protected void onCleared() {
        super.onCleared();
        LocalBroadcastManager.getInstance(getApplication()).unregisterReceiver(receiver);
    }

    public LiveData<Long> getTimerValue() {
        return timerValue;
    }

    public void setTimerValue(long timerValue) {
        this.timerValue.setValue(timerValue);
    }

    public LiveData<Integer> getRepeatCount() {
        return repeatCount;
    }

    public void setRepeatCount(int repeatCount) {
        this.repeatCount.setValue(repeatCount);
    }
}
