package com.example.time2t3yourpills;

import static androidx.constraintlayout.helper.widget.MotionEffect.TAG;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.time2t3yourpills.adapters.MedicationAdapter;
import com.example.time2t3yourpills.models.Medication;

import java.util.List;

public class MedicationFragment extends Fragment {

    private MedicationViewModel medicationViewModel;
    private SharedViewModel sharedViewModel;
    private EditText medicationNameEditText;
    private EditText dosageEditText;
    private EditText timerEditText;
    private EditText repeatCountEditText;
    private String currentMedicationId;

    @Nullable
    @Override
    public View onCreateView(LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_medication, container, false);
        Log.d(TAG, "onCreateView called");

        RecyclerView medicationsRecyclerView = view.findViewById(R.id.medications_list);
        Button addButton = view.findViewById(R.id.add_button);
        medicationNameEditText = view.findViewById(R.id.medication_name);
        dosageEditText = view.findViewById(R.id.dosage);
        timerEditText = view.findViewById(R.id.timer);
        repeatCountEditText = view.findViewById(R.id.repeat_count);

        medicationViewModel = new ViewModelProvider(this).get(MedicationViewModel.class);
        sharedViewModel = new ViewModelProvider(requireActivity()).get(SharedViewModel.class);

        MedicationAdapter adapter = new MedicationAdapter();
        medicationsRecyclerView.setAdapter(adapter);
        medicationsRecyclerView.setLayoutManager(new LinearLayoutManager(getContext()));

        medicationViewModel.getAllMedications().observe(getViewLifecycleOwner(), medications -> {
            adapter.submitList(medications);
            if (!medications.isEmpty()) {
                Medication lastMedication = medications.get(medications.size() - 1);
                currentMedicationId = String.valueOf(lastMedication.getId());

                medicationViewModel.getCurrentMedication(currentMedicationId).observe(getViewLifecycleOwner(), medication -> {
                    if (medication != null) {
                        updateUI(medication);
                    } else {
                        Log.d(TAG, "No medication with ID: " + currentMedicationId + " exists in the database");
                    }
                });
            }
        });

        addButton.setOnClickListener(v -> {
            String medicationName = medicationNameEditText.getText().toString();
            String dosage = dosageEditText.getText().toString();
            String timer = timerEditText.getText().toString();
            String repeatCount = repeatCountEditText.getText().toString();

            if (!medicationName.isEmpty() && !dosage.isEmpty() && !timer.isEmpty() && !repeatCount.isEmpty()) {
                Medication medication = new Medication(medicationName, dosage, Long.parseLong(timer), Integer.parseInt(repeatCount));
                medicationViewModel.insertOrUpdate(medication);

                long timerValue = Long.parseLong(timer) * 60 * 1000;
                sharedViewModel.setTimerValue(timerValue);
                sharedViewModel.setRepeatCount(Integer.parseInt(repeatCount));

                Intent intent = new Intent(getContext(), TimerService.class);
                intent.setAction("SET_TIMER_VALUE");
                intent.putExtra("TIMER_VALUE", timerValue);
                getContext().startService(intent);
            } else {
                Toast.makeText(getContext(), "Please fill out all fields", Toast.LENGTH_SHORT).show();
                Log.w(TAG, "Not all fields are filled");
            }
        });

        return view;
    }

    private void updateUI(Medication medication) {
        medicationNameEditText.setText(medication.getName());
        dosageEditText.setText(medication.getDosage());
        timerEditText.setText(String.valueOf(medication.getTimer()));
        repeatCountEditText.setText(String.valueOf(medication.getRepetitions()));
        Log.d(TAG, "Updating UI with medication: " + medication.toString());
    }
}
