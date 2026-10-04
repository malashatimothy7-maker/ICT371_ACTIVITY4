-- 1. tables
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer TEXT NOT NULL,
    workstations INT NOT NULL CHECK (workstations > 0),
    status TEXT NOT NULL CHECK (status IN ('ACTIVE','CANCELLED'))
);

-- sample sessions
INSERT INTO lab_sessions (name, available_workstations)
VALUES ('Advanced DB', 10),
       ('Principals of security', 5),
       ('system design and modelling', 2);

-- 2. IF / ELSIF / ELSE 
DO $$
DECLARE v_ws INT;
BEGIN
    SELECT available_workstations INTO v_ws FROM lab_sessions WHERE name='AI Lab';
    IF v_ws = 0 THEN
        RAISE NOTICE 'Session is full';
    ELSIF v_ws <= 2 THEN
        RAISE NOTICE 'Session nearly full: % workstations left', v_ws;
    ELSE
        RAISE NOTICE 'Session has enough workstations: % left', v_ws;
    END IF;
END;
$$;

-- 3. WHILE and FOR 
DO $$
DECLARE v_reminder INT := 1;
BEGIN
    WHILE v_reminder <= 3 LOOP
        RAISE NOTICE 'Preparation reminder %', v_reminder;
        v_reminder := v_reminder + 1;
    END LOOP;

    FOR v_check IN 1..3 LOOP
        RAISE NOTICE 'Workstation check %', v_check;
    END LOOP;
END;
$$;

-- 4. Reserve procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(p_session_id INT, p_lecturer TEXT, p_ws INT)
LANGUAGE plpgsql
AS $$
DECLARE v_available INT;
BEGIN
    IF p_ws <= 0 THEN
        RAISE EXCEPTION 'Workstations requested must be positive' USING ERRCODE='22023';
    END IF;

    SELECT available_workstations INTO v_available FROM lab_sessions WHERE session_id=p_session_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Session % not found', p_session_id;
        RETURN;
    ELSIF v_available < p_ws THEN
        RAISE NOTICE 'Insufficient workstations: only % available', v_available;
        RETURN;
    END IF;

    UPDATE lab_sessions SET available_workstations = available_workstations - p_ws WHERE session_id=p_session_id;

    INSERT INTO reservations(session_id, lecturer, workstations, status)
    VALUES(p_session_id, p_lecturer, p_ws, 'ACTIVE');
END;
$$;

-- 5. Call reserve_workstations
CALL reserve_workstations(1,'Dr. Smith',3);  
CALL reserve_workstations(2,'Prof. Jones',2);  
CALL reserve_workstations(3,'Dr. Lee',5);     
-- Check tables
SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. Cancel procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE v_session INT; v_ws INT; v_status TEXT;
BEGIN
    SELECT session_id, workstations, status INTO v_session, v_ws, v_status
    FROM reservations WHERE reservation_id=p_reservation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Reservation % not found', p_reservation_id;
        RETURN;
    ELSIF v_status='CANCELLED' THEN
        RAISE NOTICE 'Reservation % already cancelled', p_reservation_id;
        RETURN;
    END IF;

    UPDATE reservations SET status='CANCELLED' WHERE reservation_id=p_reservation_id;
    UPDATE lab_sessions SET available_workstations = available_workstations + v_ws WHERE session_id=v_session;
END;
$$;


CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- 7. Explicit cursor 
DO $$
DECLARE cur CURSOR FOR SELECT name, available_workstations FROM lab_sessions WHERE available_workstations <= 2;
rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations: % (% left)', rec.name, rec.available_workstations;
    END LOOP;
    CLOSE cur;
END;
$$;

-- 8. Exception handling 
CALL reserve_workstations(1,'Dr. Adams',0);  

-- 9. Final queries
SELECT * FROM lab_sessions;
SELECT * FROM reservations;





