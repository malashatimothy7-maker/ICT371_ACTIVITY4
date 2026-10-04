--1.
CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES books(book_id),
    student_number TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status TEXT NOT NULL CHECK (status IN ('ACTIVE','RETURNED'))
);
INSERT INTO books (title, available_copies)
VALUES ('Advanced Databases', 3),
       ('principals of security', 1),
       ('System design and modelling', 5);
--2.
DO $$
DECLARE v_copies INT;
BEGIN
    SELECT available_copies INTO v_copies FROM books WHERE title='Operating Systems';
    IF v_copies = 0 THEN
        RAISE NOTICE 'Book unavailable';
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Low copies: %', v_copies;
    ELSE
        RAISE NOTICE 'Sufficiently stocked: %', v_copies;
    END IF;
END;
$$;

-- 3. WHILE and FOR 
DO $$
DECLARE v_day INT := 1;
BEGIN
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Reminder %', v_day;
        v_day := v_day + 1;
    END LOOP;

    FOR v_shelf IN 1..3 LOOP
        RAISE NOTICE 'Shelf %', v_shelf;
    END LOOP;
END;
$$;

-- 4. Borrow procedure
CREATE OR REPLACE PROCEDURE borrow_book(p_book_id INT, p_student TEXT, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE v_available INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE='22023';
    END IF;

    SELECT available_copies INTO v_available FROM books WHERE book_id=p_book_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Book % not found', p_book_id;
        RETURN;
    ELSIF v_available < p_qty THEN
        RAISE NOTICE 'Insufficient copies: only % available', v_available;
        RETURN;
    END IF;

    UPDATE books SET available_copies = available_copies - p_qty WHERE book_id=p_book_id;

    INSERT INTO book_loans(book_id, student_number, quantity, status)
    VALUES(p_book_id, p_student, p_qty, 'ACTIVE');
END;
$$;

-- 5. Call borrow_book
CALL borrow_book(1,'STU001',1);  -- valid
CALL borrow_book(3,'STU002',2);  -- valid
CALL borrow_book(2,'STU003',5);  -- exceeds stock


SELECT * FROM books;
SELECT * FROM book_loans;

-- 6. Return procedure
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE v_book INT; v_qty INT; v_status TEXT;
BEGIN
    SELECT book_id, quantity, status INTO v_book, v_qty, v_status
    FROM book_loans WHERE loan_id=p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan % not found', p_loan_id;
        RETURN;
    ELSIF v_status='RETURNED' THEN
        RAISE NOTICE 'Loan % already returned', p_loan_id;
        RETURN;
    END IF;

    UPDATE book_loans SET status='RETURNED' WHERE loan_id=p_loan_id;
    UPDATE books SET available_copies = available_copies + v_qty WHERE book_id=v_book;
END;
$$;


CALL return_book(1);
CALL return_book(1);  

-- 7. Explicit cursor 
DO $$
DECLARE cur CURSOR FOR SELECT title, available_copies FROM books WHERE available_copies <= 2;
rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few copies: % (% left)', rec.title, rec.available_copies;
    END LOOP;
    CLOSE cur;
END;
$$;

-- 8. Exception handling 
CALL borrow_book(1,'STU004',0);  

-- 9. Final queries
SELECT * FROM books;
SELECT * FROM book_loans;

