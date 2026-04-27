package com.example.time2t3yourpills;

        import android.view.View;
        import android.widget.TextView;

        import androidx.annotation.NonNull;
        import androidx.recyclerview.widget.RecyclerView;

public class MedicationViewHolder extends RecyclerView.ViewHolder {
    public TextView medicationName, dosage, timer, repeatCount;  // Added repeatCount

    public MedicationViewHolder(@NonNull View itemView) {
        super(itemView);
        medicationName = itemView.findViewById(R.id.medication_name);
        dosage = itemView.findViewById(R.id.dosage);
        timer = itemView.findViewById(R.id.timer);
        repeatCount = itemView.findViewById(R.id.repeat_count);  // Initialized repeatCount
    }
}