CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    tool_name VARCHAR(100) NOT NULL,
    available_quantity INTEGER NOT NULL CHECK (available_quantity >= 0)
);
    
CREATE TABLE tool_loans (
    loan_id SERIAL PRIMARY KEY,
    tool_id  INTEGER NOT NULL REFERENCES tools(tool_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'ISSUED'
        CHECK (status IN ('ISSUED', 'RETURNED'))
);

INSERT INTO tools(tool_name, available_quantity) VALUES
('Screwdriver', 30), ('Hammer', 12), ('Spanner', 4);

DO $$
DECLARE v_quantity INTEGER;
BEGIN
    SELECT available_quantity INTO v_quantity FROM tools WHERE tool_id = 1;
    IF v_quantity = 0 THEN
        RAISE NOTICE 'Screwdriver is UNAVAILABLE.';
    ELSIF v_quantity <= 5 THEN
        RAISE NOTICE 'Screwdriver is LOW ON STOCK.';
    ELSE
        RAISE NOTICE 'Screwdriver is READILY AVAILABLE.';
    END IF;
END $$;

DO $$
DECLARE i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Safety reminder %: Wear appropriate protective equipment.', i;
        i := i + 1;
    END LOOP;
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Tool inspection number %', i;
    END LOOP;
END $$;


CREATE OR REPLACE PROCEDURE issue_tool(
    p_tool_id INTEGER, p_student_number VARCHAR, p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE v_available INTEGER;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Tool quantity must be greater than zero.';
    END IF;
    IF p_student_number IS NULL OR btrim(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT available_quantity INTO v_available
    FROM tools WHERE tool_id = p_tool_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tool % does not exist.', p_tool_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE NOTICE 'Loan rejected: requested %, available %.',
            p_quantity, v_available;
        RETURN;
    END IF;

    UPDATE tools SET available_quantity = available_quantity - p_quantity
    WHERE tool_id = p_tool_id;
    INSERT INTO tool_loans(tool_id, student_number, quantity)
    VALUES (p_tool_id, p_student_number, p_quantity);
    RAISE NOTICE 'Tool loan recorded successfully.';
END;
$$;
CALL issue_tool(1, 'STU001', 5);
CALL issue_tool(2, 'STU002', 3);
CALL issue_tool(3, 'STU003', 10);
SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;


CREATE OR REPLACE PROCEDURE return_tool(p_loan_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tool_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT tool_id, quantity, status
    INTO v_tool_id, v_quantity, v_status
    FROM tool_loans WHERE loan_id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist.', p_loan_id;
    END IF;
    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % already returned; stock not increased again.',
            p_loan_id;
        RETURN;
    END IF;

    UPDATE tools SET available_quantity = available_quantity + v_quantity
    WHERE tool_id = v_tool_id;
    UPDATE tool_loans SET status = 'RETURNED' WHERE loan_id = p_loan_id;
    RAISE NOTICE 'Tool returned and stock restored.';
END;
$$;
CALL return_tool(1);
CALL return_tool(1);

DO $$
DECLARE
    tool_cursor CURSOR FOR
        SELECT tool_name, available_quantity
        FROM tools WHERE available_quantity <= 5;
    v_name VARCHAR(100);
    v_available INTEGER;
BEGIN
    OPEN tool_cursor;
    LOOP
        FETCH tool_cursor INTO v_name, v_available;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low availability: % has % tool(s).', v_name, v_available;
    END LOOP;
    CLOSE tool_cursor;
END $$;

DO $$
BEGIN
    CALL issue_tool(1, 'STU004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Handled invalid tool request: %', SQLERRM;
END $$;

SELECT * FROM tools ORDER BY tool_id;
SELECT * FROM tool_loans ORDER BY loan_id;


