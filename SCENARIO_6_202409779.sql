CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    available_seats INTEGER NOT NULL CHECK (available_seats >= 0),
    total_seats INTEGER NOT NULL CHECK (total_seats >= 0)
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INTEGER NOT NULL REFERENCES events(event_id),
    student_number VARCHAR(30) NOT NULL,
    seat_count INTEGER NOT NULL CHECK (seat_count > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'BOOKED'
        CHECK (status IN ('BOOKED', 'CANCELLED'))
);
INSERT INTO events(event_name, available_seats, total_seats) VALUES
('ICT Career Day', 100, 100),
('Science Exhibition', 15, 15),
('Student Awards', 4, 4);

DO $$
DECLARE v_seats INTEGER;
BEGIN
    SELECT available_seats INTO v_seats FROM events WHERE event_id = 1;
    IF v_seats = 0 THEN
        RAISE NOTICE 'ICT Career Day is FULL.';
    ELSIF v_seats <= 10 THEN
        RAISE NOTICE 'ICT Career Day is NEARLY FULL.';
    ELSE
        RAISE NOTICE 'ICT Career Day has PLENTY OF SEATS.';
    END IF;
END $$;
DO $$
DECLARE i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Booking reminder day %: Confirm event booking details.', i;
        i := i + 1;
    END LOOP;
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Entrance check number %', i;
    END LOOP;
END $$;


CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id INTEGER, p_student_number VARCHAR, p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE v_available INTEGER;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Number of seats must be greater than zero.';
    END IF;
    IF p_student_number IS NULL OR btrim(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT available_seats INTO v_available
    FROM events WHERE event_id = p_event_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event % does not exist.', p_event_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE NOTICE 'Booking rejected: requested %, available %.',
            p_quantity, v_available;
        RETURN;
    END IF;

    UPDATE events SET available_seats = available_seats - p_quantity
    WHERE event_id = p_event_id;
    INSERT INTO bookings(event_id, student_number, seat_count)
    VALUES (p_event_id, p_student_number, p_quantity);
    RAISE NOTICE 'Seats booked successfully.';
END;
$$;

CALL book_seats(1, 'STU001', 10);
CALL book_seats(2, 'STU002', 5);
CALL book_seats(3, 'STU003', 8);
SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;


CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN
    SELECT event_id, seat_count, status
    INTO v_event_id, v_quantity, v_status
    FROM bookings WHERE booking_id = p_booking_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking % does not exist.', p_booking_id;
    END IF;
    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking % already cancelled; seats not released again.',
            p_booking_id;
        RETURN;
    END IF;

    UPDATE events SET available_seats = available_seats + v_quantity
    WHERE event_id = v_event_id;
    UPDATE bookings SET status = 'CANCELLED'
    WHERE booking_id = p_booking_id;
    RAISE NOTICE 'Booking cancelled and seats released.';
END;
$$;
CALL cancel_booking(1);
CALL cancel_booking(1);

DO $$
DECLARE
    event_cursor CURSOR FOR
        SELECT event_name, available_seats
        FROM events WHERE available_seats <= 10;
    v_name VARCHAR(100);
    v_available INTEGER;
BEGIN
    OPEN event_cursor;
    LOOP
        FETCH event_cursor INTO v_name, v_available;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/nearly full: % has % seat(s) remaining.',
            v_name, v_available;
    END LOOP;
    CLOSE event_cursor;
END $$;

DO $$
BEGIN
    CALL book_seats(1, 'STU004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Handled invalid booking: %', SQLERRM;
END $$;

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

