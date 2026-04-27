package com.example.time2t3yourpills;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.Observer;
import androidx.lifecycle.ViewModelProvider;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

public class TimerFragment extends Fragment {

    private TimerService timerService;
    private boolean isBound = false;
    private Button startButton;
    private Button confirmButton;
    private TextView timerText;
    private SharedViewModel sharedViewModel;
    private long lastTimerValue;
    private int lastRepeatCount;

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        Log.d("TimerFragment", "onViewCreated called");
        sharedViewModel = new ViewModelProvider(requireActivity()).get(SharedViewModel.class);
        sharedViewModel.getTimerValue().observe(getViewLifecycleOwner(), new Observer<Long>() {
            @Override
            public void onChanged(Long timerValue) {
                if (timerValue != null) {
                    lastTimerValue = timerValue;
                }
            }
        });

        sharedViewModel.getRepeatCount().observe(getViewLifecycleOwner(), new Observer<Integer>() {
            @Override
            public void onChanged(Integer repeatCount) {
                if (repeatCount != null) {
                    lastRepeatCount = repeatCount;
                }
            }
        });
    }

    @Nullable
    @Override
    public View onCreateView(LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_timer, container, false);

        timerText = view.findViewById(R.id.timer_text);
        startButton = view.findViewById(R.id.start_button);
        confirmButton = view.findViewById(R.id.confirm_button);

        startButton.setOnClickListener(v -> {
            if (isBound) {
                timerService.startTimerFromService();
            }
        });

        confirmButton.setOnClickListener(v -> {
            if (isBound) {
                timerService.onConfirmationReceived();
            }
        });

        return view;
    }

    @Override
    public void onResume() {
        super.onResume();
        LocalBroadcastManager.getInstance(requireContext())
                .registerReceiver(timerUpdateReceiver, new IntentFilter(TimerService.ACTION_TIMER_UPDATE));
    }

    @Override
    public void onPause() {
        super.onPause();
        LocalBroadcastManager.getInstance(requireContext()).unregisterReceiver(timerUpdateReceiver);
    }

    @Override
    public void onStart() {
        super.onStart();
        Intent intent = new Intent(getActivity(), TimerService.class);
        getActivity().bindService(intent, connection, Context.BIND_AUTO_CREATE);
    }

    @Override
    public void onStop() {
        super.onStop();
        if (isBound) {
            getActivity().unbindService(connection);
            isBound = false;
        }
    }

    private final ServiceConnection connection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            TimerService.TimerBinder binder = (TimerService.TimerBinder) service;
            timerService = binder.getService();
            isBound = true;
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            isBound = false;
        }
    };

    private final BroadcastReceiver timerUpdateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            long millisUntilFinished = intent.getLongExtra(TimerService.EXTRA_TIMER_VALUE, 0L);
            boolean isRunning = intent.getBooleanExtra("is_running", false);

            updateTimerLabel(millisUntilFinished);
            startButton.setVisibility(isRunning ? View.GONE : View.VISIBLE);
        }
    };

    private void updateTimerLabel(long millisUntilFinished) {
        int seconds = (int) (millisUntilFinished / 1000);
        timerText.setText("Осталось времени: " + seconds + " сек.");
    }
}
