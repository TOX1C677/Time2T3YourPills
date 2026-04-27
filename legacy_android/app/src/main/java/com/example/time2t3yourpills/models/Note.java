package com.example.time2t3yourpills.models;

import androidx.room.ColumnInfo;
import androidx.room.Entity;
import androidx.room.ForeignKey;
import androidx.room.Index;
import androidx.room.PrimaryKey;

@Entity(
        tableName = "note_table",
        foreignKeys = @ForeignKey(
                entity = User.class,
                parentColumns = "id",
                childColumns = "userId",
                onDelete = ForeignKey.CASCADE
        ),
        indices = {@Index("userId")}
)
public class Note {

    @PrimaryKey(autoGenerate = true)
    private int id;

    @ColumnInfo(name = "note_text")
    private String noteText;

    @ColumnInfo(name = "userId")
    private int userId;  // добавлено поле userId

    // Геттеры
    public int getId() {
        return id;
    }

    public String getNoteText() {
        return noteText;
    }

    public int getUserId() {  // новый геттер для userId
        return userId;
    }

    // Сеттеры
    public void setId(int id) {
        this.id = id;
    }

    public void setNoteText(String noteText) {
        this.noteText = noteText;
    }

    public void setUserId(int userId) {  // новый сеттер для userId
        this.userId = userId;
    }

    // Добавьте другие геттеры и сеттеры здесь, если это необходимо

}
