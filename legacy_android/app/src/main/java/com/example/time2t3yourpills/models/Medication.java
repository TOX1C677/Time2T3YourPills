package com.example.time2t3yourpills.models;

        import androidx.annotation.NonNull;
        import androidx.room.Entity;
        import androidx.room.PrimaryKey;

        import java.util.Objects;
        import java.util.UUID;

@Entity(tableName = "medication_table")
public class Medication {
    @PrimaryKey
    @NonNull
    private String id = UUID.randomUUID().toString(); // Unique ID using UUID
    private String name;
    private String dosage;
    private long timer;
    private int repetitions;

    // Конструктор
    public Medication(String name, String dosage, long timer, int repetitions) {
        this.name = name;
        this.dosage = dosage;
        this.timer = timer;
        this.repetitions = repetitions;
    }

    // Getters
    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getDosage() {
        return dosage;
    }

    public long getTimer() {
        return timer;
    }

    public int getRepetitions() {
        return repetitions;
    }

    // Setters
    public void setId(String id) {
        this.id = id;
    }

    public void setName(String name) {
        this.name = name;
    }

    public void setDosage(String dosage) {
        this.dosage = dosage;
    }

    public void setTimer(long timer) {
        this.timer = timer;
    }

    public void setRepetitions(int repetitions) {
        this.repetitions = repetitions;
    }

    // Override equals method
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Medication that = (Medication) o;
        return timer == that.timer &&
                repetitions == that.repetitions &&
                Objects.equals(id, that.id) &&
                Objects.equals(name, that.name) &&
                Objects.equals(dosage, that.dosage);
    }

}
