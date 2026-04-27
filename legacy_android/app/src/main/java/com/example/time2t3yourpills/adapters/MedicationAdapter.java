package com.example.time2t3yourpills.adapters;

import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.ListAdapter;

import com.example.time2t3yourpills.MedicationViewHolder;
import com.example.time2t3yourpills.R;
import com.example.time2t3yourpills.models.Medication;

public class MedicationAdapter extends ListAdapter<Medication, MedicationViewHolder> {

    // Constructor
    public MedicationAdapter() {
        super(new MedicationDiffCallback());
    }

    @NonNull
    @Override
    public MedicationViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.medication_list_item, parent, false);
        return new MedicationViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull MedicationViewHolder holder, int position) {
        //Medication medication = getItem(position);
        //Log.d("MedicationAdapter", "Binding item at position: " + position + ", Medication name: " + medication.getName());
        //holder.medicationName.setText(medication.getName());
        //holder.dosage.setText(String.valueOf(medication.getDosage()));
        //holder.timer.setText(String.valueOf(medication.getTimer()));
    }



    // DiffUtil.ItemCallback for Medication objects
    static class MedicationDiffCallback extends DiffUtil.ItemCallback<Medication> {

        @Override
        public boolean areItemsTheSame(@NonNull Medication oldItem, @NonNull Medication newItem) {
            // Assuming Medication has an ID field that uniquely identifies it.
            // Replace with your own logic if necessary.
            return oldItem.getId() == newItem.getId();
        }

        @Override
        public boolean areContentsTheSame(@NonNull Medication oldItem, @NonNull Medication newItem) {
            // Replace with your own logic if necessary.
            return oldItem.equals(newItem);
        }
    }
}
