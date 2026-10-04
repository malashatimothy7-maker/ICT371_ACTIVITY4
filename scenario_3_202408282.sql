-- 1.  tables
CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    available_beds INT NOT NULL CHECK (available_beds >= 0)
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INT REFERENCES hostel_rooms(room_id),
    student_number TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('ACTIVE','CHECKED_OUT'))
);

-- sample rooms
INSERT INTO hostel_rooms (name, available_beds)
VALUES ('Room A', 2),
       ('Room B', 1),
       ('Room C', 3);

-- 2. IF / ELSIF / ELSE
DO $$
DECLARE v_beds INT;
BEGIN
    SELECT available_beds INTO v_beds FROM hostel_rooms WHERE name='Room B';
    IF v_beds = 0 THEN
        RAISE NOTICE 'Room is full';
    ELSIF v_beds = 1 THEN
        RAISE NOTICE 'Room has one space left';
    ELSE
        RAISE NOTICE 'Room has several spaces: % left', v_beds;
    END IF;
END;
$$;

-- 3. WHILE and FOR 
DO $$
DECLARE v_day INT := 1;
BEGIN
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Inspection day %', v_day;
        v_day := v_day + 1;
    END LOOP;

    FOR v_check IN 1..3 LOOP
        RAISE NOTICE 'Room check %', v_check;
    END LOOP;
END;
$$;

-- 4. Allocate procedure
CREATE OR REPLACE PROCEDURE allocate_room(p_room_id INT, p_student TEXT)
LANGUAGE plpgsql
AS $$
DECLARE v_beds INT;
BEGIN
    IF p_student IS NULL OR p_student = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank' USING ERRCODE='22023';
    END IF;

    SELECT available_beds INTO v_beds FROM hostel_rooms WHERE room_id=p_room_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Room % not found', p_room_id;
        RETURN;
    ELSIF v_beds < 1 THEN
        RAISE NOTICE 'Room % is full', p_room_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms SET available_beds = available_beds - 1 WHERE room_id=p_room_id;

    INSERT INTO allocations(room_id, student_number, status)
    VALUES(p_room_id, p_student, 'ACTIVE');
END;
$$;

-- 5. Call allocate_room
CALL allocate_room(1,'STU001');  -- valid
CALL allocate_room(3,'STU002');  -- valid
CALL allocate_room(2,'STU003');  -- room B has only 1 bed, may fail if already full


SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. Check-out procedure
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE v_room INT; v_status TEXT;
BEGIN
    SELECT room_id, status INTO v_room, v_status
    FROM allocations WHERE allocation_id=p_allocation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Allocation % not found', p_allocation_id;
        RETURN;
    ELSIF v_status='CHECKED_OUT' THEN
        RAISE NOTICE 'Allocation % already checked out', p_allocation_id;
        RETURN;
    END IF;

    UPDATE allocations SET status='CHECKED_OUT' WHERE allocation_id=p_allocation_id;
    UPDATE hostel_rooms SET available_beds = available_beds + 1 WHERE room_id=v_room;
END;
$$;


CALL check_out(1);
CALL check_out(1);  

-- 7. Explicit cursor 
DO $$
DECLARE cur CURSOR FOR SELECT name, available_beds FROM hostel_rooms WHERE available_beds <= 1;
rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Room nearly full or full: % (% beds left)', rec.name, rec.available_beds;
    END LOOP;
    CLOSE cur;
END;
$$;

-- 8. Exception handling 
CALL allocate_room(1,''); 

-- 9. Final queries
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;




