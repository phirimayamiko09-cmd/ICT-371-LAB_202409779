CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);
SELECT*FROM medicines
CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INTEGER NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
        CHECK (status IN ('DISPENSED', 'REVERSED'))
);
INSERT INTO medicines(medicine_name, stock_quantity) VALUES
('Paracetamol', 50), ('Antacid', 12), ('Oral Rehydration Salts', 4);

DO $$
DECLARE v_stock INTEGER;
BEGIN
    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = 1;
    IF v_stock = 0 THEN
        RAISE NOTICE 'Paracetamol is OUT OF STOCK.';
    ELSIF v_stock <= 10 THEN
        RAISE NOTICE 'Paracetamol is LOW ON STOCK.';
    ELSE
        RAISE NOTICE 'Paracetamol is SUFFICIENTLY STOCKED.';
    END IF;
END $$;

DO $$
DECLARE i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock review day %: Check medicine quantities.', i;
        i := i + 1;
    END LOOP;
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number %', i;
    END LOOP;
END $$;


CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INTEGER, p_student_number VARCHAR, p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE v_stock INTEGER;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Dispensing quantity must be greater than zero.';
    END IF;
    IF p_student_number IS NULL OR btrim(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines WHERE medicine_id = p_medicine_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine % does not exist.', p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE NOTICE 'Dispensing rejected: requested %, available %.',
            p_quantity, v_stock;
        RETURN;
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;
    INSERT INTO dispensing_records(medicine_id, student_number, quantity)
    VALUES (p_medicine_id, p_student_number, p_quantity);
    RAISE NOTICE 'Medicine dispensed and recorded.';
END;
$$;

CALL dispense_medicine(1, 'STU001', 8);
CALL dispense_medicine(2, 'STU002', 3);
CALL dispense_medicine(3, 'STU003', 20);
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;


CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT medicine_id, quantity, status
    INTO v_medicine_id, v_quantity, v_status
    FROM dispensing_records WHERE record_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record % does not exist.', p_record_id;
    END IF;
    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % already reversed; stock not restored again.',
            p_record_id;
        RETURN;
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;
    UPDATE dispensing_records SET status = 'REVERSED'
    WHERE record_id = p_record_id;
    RAISE NOTICE 'Dispensing reversed and stock restored.';
END;
$$;
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

DO $$
DECLARE
    medicine_cursor CURSOR FOR
        SELECT medicine_name, stock_quantity
        FROM medicines WHERE stock_quantity < 10;
    v_name VARCHAR(100);
    v_stock INTEGER;
BEGIN
    OPEN medicine_cursor;
    LOOP
        FETCH medicine_cursor INTO v_name, v_stock;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: % has % unit(s).', v_name, v_stock;
    END LOOP;
    CLOSE medicine_cursor;
END $$;

DO $$
BEGIN
    CALL dispense_medicine(1, 'STU004', -2);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Handled invalid dispensing request: %', SQLERRM;
END $$;

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

