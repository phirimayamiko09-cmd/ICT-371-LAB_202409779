DROP SCHEMA IF EXISTS ict371_s2 CASCADE;
CREATE SCHEMA ict371_s2;
SET search_path TO ict371_s2;

-- TASK 1: Create tables and insert at least three sessions.
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INTEGER NOT NULL CHECK (available_workstations >= 0),
    total_workstations INTEGER NOT NULL CHECK (total_workstations >= 0)
);
SELECT*FROM lab_sessions
CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstation_count INTEGER NOT NULL CHECK (workstation_count > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'CANCELLED'))
);
SELECT*FROM reservations
INSERT INTO lab_sessions(session_name, available_workstations, total_workstations) VALUES
('Database Practical', 20, 20),
('Networking Practical', 8, 8),
('Programming Practical', 3, 3);
DO $$
DECLARE
    v_available INTEGER;
BEGIN
    SELECT available_workstations
    INTO v_available
    FROM ict371_s2.lab_sessions
    WHERE session_id = 1;

    IF v_available = 0 THEN
        RAISE NOTICE 'Database Practical is FULL.';
    ELSIF v_available <= 5 THEN
        RAISE NOTICE 'Database Practical is NEARLY FULL.';
    ELSE
        RAISE NOTICE 'Database Practical has ENOUGH workstations.';
    END IF;

END $$;
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Reminder %: Prepare the laboratory before the session.', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation check number %', i;
    END LOOP;
END $$;
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INTEGER, p_lecturer VARCHAR, p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INTEGER;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Workstation quantity must be greater than zero.';
    END IF;

    SELECT available_workstations INTO v_available
    FROM lab_sessions WHERE session_id = p_session_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session % does not exist.', p_session_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE NOTICE 'Reservation rejected: requested %, available %.',
            p_quantity, v_available;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_quantity
    WHERE session_id = p_session_id;

    INSERT INTO reservations(session_id, lecturer, workstation_count)
    VALUES (p_session_id, p_lecturer, p_quantity);
    RAISE NOTICE 'Reservation recorded successfully.';
END;
$$;
CALL reserve_workstations(1, 'Lecturer A', 5);
CALL reserve_workstations(2, 'Lecturer B', 3);
CALL reserve_workstations(3, 'Lecturer C', 10);
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

CREATE OR REPLACE PROCEDURE ict371_s2.cancel_reservation(
    p_reservation_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT session_id, workstation_count, status
    INTO v_session_id, v_quantity, v_status
    FROM ict371_s2.reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % does not exist.',
            p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % was already cancelled; no capacity restored.',
            p_reservation_id;
        RETURN;
    END IF;

    UPDATE ict371_s2.lab_sessions
    SET available_workstations =
        available_workstations + v_quantity
    WHERE session_id = v_session_id;

    UPDATE ict371_s2.reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;

    RAISE NOTICE 'Reservation cancelled and workstations released.';
END;
$$;
CALL ict371_s2.cancel_reservation(1);


DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT session_name, available_workstations
        FROM ict371_lab.lab_sessions
        WHERE available_workstations <= 5
    LOOP
        RAISE NOTICE 'Session: %, Available Workstations: %',
            rec.session_name, rec.available_workstations;
    END LOOP;
END $$;
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name = 'lab_sessions';
DO $$
BEGIN
    CALL reserve_workstations(1, 'Lecturer Invalid', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Handled invalid reservation: %', SQLERRM;
END $$;


SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name IN ('lab_sessions', 'reservations')
ORDER BY table_schema, table_name;
SELECT * FROM public.lab_sessions ORDER BY session_id;
SELECT * FROM public.reservations ORDER BY reservation_id;
