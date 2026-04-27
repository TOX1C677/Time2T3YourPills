package com.example.time2t3yourpills.dao;

import androidx.lifecycle.LiveData;
import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.Query;
import androidx.room.Update;

import com.example.time2t3yourpills.models.Note;

import java.util.List;

@Dao
public interface NoteDao {

    @Insert
    void insert(Note note);

    @Update
    void update(Note note);

    @Query("SELECT * FROM note_table")
    LiveData<List<Note>> getAllNotes();

    @Query("SELECT * FROM note_table WHERE id = :noteId LIMIT 1")
    Note getNoteSync(int noteId);

    @Query("DELETE FROM note_table WHERE id = :noteId")
    void deleteNote(int noteId);

    @Query("SELECT * FROM note_table WHERE userId = :userId")
    LiveData<List<Note>> getNotesForUser(int userId);


    @Query("SELECT * FROM note_table WHERE id = :noteId")
    LiveData<Note> getNote(int noteId);
}
