-- 1.  tables
CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0)
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id),
    student_number TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status TEXT NOT NULL CHECK (status IN ('ACTIVE','REVERSED'))
);

--  sample medicines
INSERT INTO medicines (name, stock)
VALUES ('Paracetamol', 20),
       ('Amoxicillin', 5),
       ('Ibuprofen', 0);

-- 2. IF / ELSIF / ELSE 
DO $$
DECLARE v_stock INT;
BEGIN
    SELECT stock INTO v_stock FROM medicines WHERE name='Amoxicillin';
    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine out of stock';
    ELSIF v_stock <= 2 THEN
        RAISE NOTICE 'Medicine low on stock: % left', v_stock;
    ELSE
        RAISE NOTICE 'Medicine sufficiently stocked: % left', v_stock;
    END IF;
END;
$$;

-- 3. WHILE and FOR 
DO $$
DECLARE v_day INT := 1;
BEGIN
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Stock review day %', v_day;
        v_day := v_day + 1;
    END LOOP;

    FOR v_shelf IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection %', v_shelf;
    END LOOP;
END;
$$;

-- 4. Dispense procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(p_medicine_id INT, p_student TEXT, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE v_stock INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE='22023';
    END IF;

    SELECT stock INTO v_stock FROM medicines WHERE medicine_id=p_medicine_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Medicine % not found', p_medicine_id;
        RETURN;
    ELSIF v_stock < p_qty THEN
        RAISE NOTICE 'Insufficient stock: only % available', v_stock;
        RETURN;
    END IF;

    UPDATE medicines SET stock = stock - p_qty WHERE medicine_id=p_medicine_id;

    INSERT INTO dispensing_records(medicine_id, student_number, quantity, status)
    VALUES(p_medicine_id, p_student, p_qty, 'ACTIVE');
END;
$$;

-- 5.  dispense_medicine
CALL dispense_medicine(1,'STU001',5);  -- valid
CALL dispense_medicine(2,'STU002',2);  -- valid
CALL dispense_medicine(3,'STU003',1);  -- exceeds stock (Ibuprofen is 0)


SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. Reverse procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE v_med INT; v_qty INT; v_status TEXT;
BEGIN
    SELECT medicine_id, quantity, status INTO v_med, v_qty, v_status
    FROM dispensing_records WHERE record_id=p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Record % not found', p_record_id;
        RETURN;
    ELSIF v_status='REVERSED' THEN
        RAISE NOTICE 'Record % already reversed', p_record_id;
        RETURN;
    END IF;

    UPDATE dispensing_records SET status='REVERSED' WHERE record_id=p_record_id;
    UPDATE medicines SET stock = stock + v_qty WHERE medicine_id=v_med;
END;
$$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);  

-- 7. Explicit cursor 
DO $$
DECLARE cur CURSOR FOR SELECT name, stock FROM medicines WHERE stock <= 2;
rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low-stock medicine: % (% left)', rec.name, rec.stock;
    END LOOP;
    CLOSE cur;
END;
$$;

-- 8. Exception handling 
CALL dispense_medicine(1,'STU004',-3); 

-- 9. Final queries
SELECT * FROM medicines;
SELECT * FROM dispensing_records;



