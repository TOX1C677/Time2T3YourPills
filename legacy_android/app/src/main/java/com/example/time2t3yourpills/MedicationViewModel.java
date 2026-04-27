package com.example.time2t3yourpills;

import static androidx.constraintlayout.helper.widget.MotionEffect.TAG;

import android.app.Application;
import android.os.AsyncTask;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.time2t3yourpills.models.Medication;
import com.example.time2t3yourpills.repository.MedicationRepository;

import java.util.List;

public class MedicationViewModel extends AndroidViewModel {

    private MedicationRepository medicationRepository;
    private LiveData<List<Medication>> allMedications;
    private LiveData<Medication> currentMedication;

    public MutableLiveData<String> medicationName = new MutableLiveData<>();
    public MutableLiveData<String> dosage = new MutableLiveData<>();
    public MutableLiveData<Long> timer = new MutableLiveData<>();
    public MutableLiveData<Integer> repeatCount = new MutableLiveData<>();

    public MedicationViewModel(@NonNull Application application) {
        super(application);
        medicationRepository = new MedicationRepository(application);
        allMedications = medicationRepository.getAllMedications();
    }

    public LiveData<Medication> getCurrentMedication(String id) {
        if (currentMedication == null) {
            currentMedication = medicationRepository.getMedicationById(id);
        }
        return currentMedication;
    }

    public LiveData<List<Medication>> getAllMedications() {
        return allMedications;
    }

    public String insertOrUpdate(Medication medication) {
        final String[] newId = new String[1];
        AsyncTask.execute(() -> {
            Medication existingMedication = medicationRepository.getMedicationByIdSync(medication.getId());
            if (existingMedication == null) {
                medicationRepository.insert(medication);
                newId[0] = medication.getId();
                Log.d(TAG, "Inserted new medication with ID: " + medication.getId());
            } else {
                medicationRepository.update(medication);
                newId[0] = medication.getId();
                Log.d(TAG, "Updated existing medication with ID: " + medication.getId());
            }

            // Обновляем каждый MutableLiveData с новыми данными
            new Handler(Looper.getMainLooper()).post(() -> {
                medicationName.setValue(medication.getName());
                dosage.setValue(medication.getDosage());
                timer.setValue(medication.getTimer());
                repeatCount.setValue(medication.getRepetitions());
            });
        });
        return newId[0];
    }
}
