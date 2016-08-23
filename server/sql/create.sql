create table HOST(
SITEID		                               CHAR(6) NOT NULL,
IPADDRESS                                  VARCHAR2(45) NOT NULL,
USERNAME                                   VARCHAR2(20),
PASSWORD                                   VARCHAR2(255),
ROOTPASS								   VARCHAR2(255),
PORT                                       NUMBER(5),
ROLE									   VARCHAR2(255)
);


create table HOST(
SITEID		                               CHAR(6) NOT NULL,
IPADDRESS                                  VARCHAR(45) NOT NULL,
USERNAME                                   VARCHAR(20),
PASSWORD                                   VARCHAR(255),
ROOTPASS								   VARCHAR(255),
PORT                                       integer(5),
ROLE									   VARCHAR(255)
);

create table HOSTSTAT(
SITEID		                               CHAR(6) NOT NULL,
IPADDRESS                                  VARCHAR(45) NOT NULL,
STATUS									   VARCHAR(20),
OS										   VARCHAR(255),
AGENTVERSION							   VARCHAR(20),
CONFVERSION								   VARCHAR(30),
REFRESHELA								   integer(10),
DATASIZE								   integer(10),
HEALTH									   VARCHAR(255)
)

create table HOSTSTAT(
SITEID		                               CHAR(6) NOT NULL,
IPADDRESS                                  VARCHAR2(45) NOT NULL,
STATUS									   VARCHAR2(20),
OS										   VARCHAR2(255),
AGENTVERSION							   VARCHAR2(20),
CONFVERSION								   VARCHAR2(30),
REFRESHELA								   NUMBER(10),
DATASIZE								   NUMBER(10),
HEALTH									   VARCHAR2(255)
)
