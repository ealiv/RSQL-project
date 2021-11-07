library("RSQLite")

db = dbConnect(SQLite(), "/Users/erbolaliev/Downloads/lahman2016.sqlite")

tbls <-  dbListTables(db)
tbls

#'* Useful Summaries *

#returns number of rows for each column
structure(sapply(tbls, function(t)
  dbGetQuery(db, sprintf("SELECT COUNT(*) FROM %s", t))[1,1]),
  names = tbls) 

#returns the names of columns
structure(lapply(tbls, function(t) dbListFields(db, t)), names = tbls)

#returns the number of columns
structure(sapply(tbls, function(t) length(dbListFields(db, t))), names = tbls)

#returns the column types for a table
structure(lapply(tbls, function(t)
  dbGetQuery(db, sprintf("PRAGMA table_info(%s)", t))),
  names = tbls)


#'* Questions to answer *

#1. What years do the data cover? are there data for each of these years?
#SELECT MIN(yearID), MAX(yearID) FROM Teams
w = sapply(tbls, function(tbl) "yearID" %in% dbListFields(db, tbl))
chk = lapply(tbls[w], function(tbl) dbGetQuery(db, sprintf("SELECT MIN(yearID), MAX(yearID) FROM %s", tbl))) 
chk = do.call(rbind, chk)
rownames(chk) = tbls[w]
chk
min(chk[,1])
max(chk[,2])
#in SQL 
dbGetQuery(db, 'SELECT MIN(yearId), MAX(yearID) FROM Teams')
#the data covers 1871 - 2016 years


#2. How many (unique) people are included in the database? How many are players, managers, etc?
dbGetQuery(db, "SELECT * from sqlite_master WHERE name = 'Master'")
dbGetQuery(db, "PRAGMA table_info(Master)")

dbGetQuery(db, "SELECT COUNT(*) FROM Master")
dbGetQuery(db, "SELECT COUNT(DISTINCT playerID) FROM Master") #getting a distinct people 
#there are 19105 distinct people

#3. How many players became managers?
dbGetQuery(db, "SELECT COUNT(DISTINCT playerID) FROM Managers") #how many distinct players in Managers 
dbGetQuery(db, "SELECT DISTINCT playerID FROM Appearances WHERE playerID IN (SELECT DISTINCT playerID
FROM Managers)") #returns the list of distinct playerID from Appearances, basucally a union of two tables
dbGetQuery(db, "SELECT COUNT(DISTINCT playerID) 
                FROM Appearances 
                WHERE playerID IN (SELECT DISTINCT playerID
                FROM Managers)") 
#there are 574 players who became managers.

dbGetQuery(db, "SELECT COUNT(DISTINCT playerID) FROM Managers")
dbGetQuery(db, 'SELECT m.playerID, COUNT(m.playerID) 
                FROM Managers AS m, Appearances AS a 
                WHERE m.playerID = a.playerID
                GROUP BY m.playerID') #returns the list of the playerID
dbGetQuery(db, 'SELECT COUNT(DISTINCT playerID) 
                FROM Appearances 
                WHERE playerID IN (SELECT DISTINCT playerID
                                   FROM Managers)') 
#there are 574 players who became managers.

dbGetQuery(db, "SELECT m.playerID, COUNT(m.playerID) 
                FROM Managers AS m, Appearances AS a 
                WHERE m.playerID = a.playerID
                GROUP BY m.playerID") #returns list of players

dbGetQuery(db, "SELECT COUNT(*) FROM (SELECT m.playerID, COUNT(m.playerID) 
                FROM Managers AS m, Appearances AS a 
                WHERE m.playerID = a.playerID 
                GROUP BY m.playerID)")
#there are 574 players who became managers.

#4. How many players are there in each year, from 2000 to 2013? Do all teams have the same number of players?
dbGetQuery(db, "SELECT yearID, COUNT(DISTINCT playerID) AS numPlayers
                FROM Appearances
                WHERE yearID BETWEEN 2000 and 2013
                GROUP BY yearID")

#5. What team won the World Series in 2010? Include the name of the team, the league and division.
dbGetQuery(db, "SELECT t.yearID, t.name, t.lgID, t.divID, s.teamIDWinner 
                FROM SeriesPost AS s,
                          Teams AS t
                WHERE s.yearID = 2010
                AND s.round = 'WS'
                AND t.yearID = 2010
                AND s.teamIDwinner = t.teamID")
#it was SF Giants, NL, W

#6. What team lost the World Series each year? Again, include the name of the team, league and division.
dbGetQuery(db, "SELECT t.yearID, t.name, t.lgID, t.divID, s.teamIDloser 
                FROM SeriesPost AS s,
                          Teams AS t
                WHERE s.yearID = t.yearID
                AND s.round = 'WS'
                AND s.teamIDloser = t.teamID ORDER BY t.yearID DESC")

#7. Compute the table of World Series winners for all years, again with the name of the team, league and division.
dbGetQuery(db, "SELECT t.yearID, t.name, t.lgID, t.divID, s.teamIDWinner 
                FROM SeriesPost AS s,
                          Teams AS t
                WHERE s.yearID = t.yearID
                AND s.round = 'WS'
                AND s.teamIDwinner = t.teamID ORDER BY s.yearID DESC")

#8. *Compute the table that has both the winner and runner-up for the World Series in each tuple/row for all years, again with the name of the team, league and division, and also the number games the losing team won in the series.
dbGetQuery(db, "SELECT s.yearID, w.name, w.lgID, w.divID,
                                 l.name, l.lgID, l.divID, s.losses
                FROM SeriesPost AS s, Teams AS w, Teams AS l 
                WHERE s.round = 'WS'
                  AND s.yearID = w.yearID
                  AND s.yearID = l.yearID
                  AND w.teamID = s.teamIDWinner 
                  AND l.teamID = s.teamIDLoser
                ORDER BY s.yearID DESC")

#9. Do you see a relationship between the number of games won in a season and winning the World Series?

dbGetQuery(db, "SELECT t.name, W AS wins, t.yearID, t.teamID, 
                        (t.teamID = p.teamIDwinner) AS wonWS
                FROM Teams AS t, SeriesPost AS p
                WHERE p.yearID = t.yearID 
                  AND p.round = 'WS'
                ORDER BY t.yearID DESC")

#10. In 2003, what were the three highest salaries? (We refer here to unique salaries, i.e., there may be several players getting the exact same amount.) How do we find the players who got any of these 3 salaries?

dbGetQuery(db, "SELECT *
                FROM Salaries AS A, Master AS B 
                WHERE yearID = 2003
                  AND A.playerID = B.playerID 
                ORDER BY salary LIMIT 3")

dbGetQuery(db, "SELECT *
                FROM Salaries AS A, Master AS B 
                WHERE yearID = 2003 AND A.playerID = B.playerID 
                  AND salary IN (SELECT salary 
                                  FROM Salaries
                                WHERE yearID = 2003)
                                LIMIT 3")

#11. For 2010, compute the total payroll of each of the different teams. Next compute the team payrolls for all years in the database for which we have salary information.

dbGetQuery(db, "SELECT t.name, SUM(s.salary) AS payroll, s.yearID, t.teamID 
                FROM Salaries AS s,
                        Teams AS t
                WHERE s.yearID = 2010
                  AND t.yearID = 2010
                  AND t.teamID = s.teamID
                GROUP BY s.teamID 
                ORDER BY payroll DESC
           ")




#call dbDisconnect() when finished working with a connection 

