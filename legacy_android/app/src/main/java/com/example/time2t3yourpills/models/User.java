package com.example.time2t3yourpills.models;

import android.util.Log;
import androidx.room.Entity;
import androidx.room.PrimaryKey;

@Entity(tableName = "user_table")
public class User {
    @PrimaryKey(autoGenerate = true)
    private int id;  // ID теперь будет генерироваться автоматически
    private String name;
    private String middleName;
    private String notes;

    // Геттеры
    public int getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getMiddleName() {
        return middleName;
    }

    public String getNotes() {
        return notes;
    }

    // Сеттеры
    public void setId(int id) {
        Log.d("UserModel", "setId called with value: " + id);
        this.id = id;
    }

    public void setName(String name) {
        Log.d("UserModel", "setName called with value: " + name);
        this.name = name;
    }

    public void setMiddleName(String middleName) {
        Log.d("UserModel", "setMiddleName called with value: " + middleName);
        this.middleName = middleName;
    }

    public void setNotes(String notes) {
        Log.d("UserModel", "setNotes called with value: " + notes);
        this.notes = notes;
    }
}
