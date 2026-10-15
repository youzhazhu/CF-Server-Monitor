-- Source: 9b46be4ec5cab39aefe54947cb9a74381cb70fc2 src/database/schema.js

      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY, 
        value TEXT
      )
    ;

      CREATE TABLE IF NOT EXISTS servers (
        id TEXT PRIMARY KEY,
        name TEXT,
        server_group TEXT DEFAULT 'Default',
        price TEXT DEFAULT '',
        expire_date TEXT DEFAULT '',
        bandwidth TEXT DEFAULT '',
        traffic_limit TEXT DEFAULT '',
        traffic_calc_type TEXT DEFAULT 'total',
        reset_day INTEGER DEFAULT 1,
        report_interval INTEGER DEFAULT 60,
        ping_mode TEXT DEFAULT 'http',
        is_hidden TEXT DEFAULT '0',
        sort_order INTEGER DEFAULT 0
      )
    ;

      CREATE TABLE IF NOT EXISTS metrics_history (
        id INTEGER PRIMARY KEY,
        server_id TEXT NOT NULL,
        timestamp INTEGER DEFAULT 0,
        cpu REAL DEFAULT 0,
        ram REAL DEFAULT 0,
        disk REAL DEFAULT 0,
        load_avg TEXT DEFAULT '0',
        net_in_speed REAL DEFAULT 0,
        net_out_speed REAL DEFAULT 0,
        net_rx REAL DEFAULT 0,
        net_tx REAL DEFAULT 0,
        processes INTEGER DEFAULT 0,
        tcp_conn INTEGER DEFAULT 0,
        udp_conn INTEGER DEFAULT 0,
        ping_ct INTEGER DEFAULT 0,
        ping_cu INTEGER DEFAULT 0,
        ping_cm INTEGER DEFAULT 0,
        ping_bd INTEGER DEFAULT 0,
        loss_ct INTEGER DEFAULT NULL,
        loss_cu INTEGER DEFAULT NULL,
        loss_cm INTEGER DEFAULT NULL,
        loss_bd INTEGER DEFAULT NULL,
        ram_total REAL DEFAULT 0,
        ram_used REAL DEFAULT 0,
        swap_total REAL DEFAULT 0,
        swap_used REAL DEFAULT 0,
        disk_total REAL DEFAULT 0,
        disk_used REAL DEFAULT 0,
        cpu_cores INTEGER DEFAULT 0,
        cpu_info TEXT DEFAULT '',
        gpu REAL DEFAULT NULL,
        gpu_info TEXT DEFAULT '',
        arch TEXT DEFAULT '',
        os TEXT DEFAULT '',
        country TEXT DEFAULT '',
        ip_v4 TEXT DEFAULT '0',
        ip_v6 TEXT DEFAULT '0',
        boot_time TEXT DEFAULT '',
        net_rx_monthly REAL DEFAULT 0,
        net_tx_monthly REAL DEFAULT 0,
        FOREIGN KEY (server_id) REFERENCES servers(id)
      )
    ;

      CREATE INDEX IF NOT EXISTS idx_history_server_time 
      ON metrics_history(server_id, timestamp)
    ;
