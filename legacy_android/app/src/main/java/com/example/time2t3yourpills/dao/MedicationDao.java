package com.example.time2t3yourpills.dao;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Delete;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.example.time2t3yourpills.models.Medication;

import java.util.List;

@Dao
public interface MedicationDao {
    @Insert
    long insert(Medication medication);

    @Update
    int update(Medication medication);

    @Delete
    int delete(Medication medication);

    @Query("SELECT * FROM medication_table")
    LiveData<List<Medication>> getAllMedications();
    @Query("SELECT * FROM medication_table WHERE id = :id LIMIT 1")
    LiveData<Medication> getMedicationById(String id);
    @Query("SELECT * FROM medication_table WHERE id = :id LIMIT 1")
    Medication getMedicationByIdSync(String id);
    @Query("DELETE FROM medication_table")
    int deleteAll();
}
