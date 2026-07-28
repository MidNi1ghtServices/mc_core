CREATE TABLE IF NOT EXISTS vehicle_tracking (
    plate VARCHAR(20) PRIMARY KEY,
    owner VARCHAR(50) NOT NULL,
    last_move INT NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    tow_time INT DEFAULT NULL
);
