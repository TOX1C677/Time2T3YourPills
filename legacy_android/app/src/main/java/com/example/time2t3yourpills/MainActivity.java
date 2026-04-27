package com.example.time2t3yourpills;

import android.content.*;
import android.os.Bundle;
import android.os.IBinder;
import android.view.MenuItem;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import com.google.android.material.bottomnavigation.BottomNavigationView;

public class MainActivity extends AppCompatActivity {
    private TimerService timerService;
    private boolean isBound;
    private SharedViewModel sharedViewModel;
    private BroadcastReceiver receiver;

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

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        sharedViewModel = new ViewModelProvider(this).get(SharedViewModel.class);
        createAndRegisterReceiver();

        BottomNavigationView bottomNav = findViewById(R.id.bottom_navigation);
        bottomNav.setOnNavigationItemSelectedListener(navListener);

        if (savedInstanceState == null) {
            replaceFragment(new TimerFragment());
        }
    }

    private void createAndRegisterReceiver() {
        receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                long millisUntilFinished = intent.getLongExtra(TimerService.EXTRA_TIMER_VALUE, 0);
                sharedViewModel.setTimerValue(millisUntilFinished);
            }
        };

        IntentFilter filter = new IntentFilter(TimerService.ACTION_TIMER_UPDATE);
        LocalBroadcastManager.getInstance(this).registerReceiver(receiver, filter);
    }

    @Override
    protected void onResume() {
        super.onResume();
        Intent intent = new Intent(this, TimerService.class);
        bindService(intent, connection, Context.BIND_AUTO_CREATE);
        startService(intent);
    }

    @Override
    protected void onPause() {
        if (isBound) {
            unbindService(connection);
            isBound = false;
        }
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        LocalBroadcastManager.getInstance(this).unregisterReceiver(receiver);
        super.onDestroy();
    }

    private final BottomNavigationView.OnNavigationItemSelectedListener navListener = item -> {
        Fragment selectedFragment = null;
        int itemId = item.getItemId();

        if (itemId == R.id.nav_timer) {
            selectedFragment = new TimerFragment();
        } else if (itemId == R.id.nav_medication) {
            selectedFragment = new MedicationFragment();
        } else if (itemId == R.id.nav_patient) {
            selectedFragment = new PatientFragment();
        } else if (itemId == R.id.nav_about) {
            selectedFragment = new AboutFragment();
        }

        if (selectedFragment != null) {
            replaceFragment(selectedFragment);
        } else {
            throw new IllegalStateException("Unexpected value: " + itemId);
        }

        return true;
    };


    private void replaceFragment(Fragment fragment) {
        getSupportFragmentManager().beginTransaction().replace(R.id.fragment_container, fragment).commit();
    }
}
