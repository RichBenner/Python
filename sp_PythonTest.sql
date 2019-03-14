IF OBJECT_ID('dbo.sp_PythonTest') IS NULL
  EXEC ('CREATE PROCEDURE dbo.sp_PythonTest AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[sp_PythonTest]
AS

/* Making a table to store our subreddit list in */
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'py_SubredditList')
BEGIN
	CREATE TABLE py_SubredditList (Subreddit varchar(50), Hits bigint)
END

/* We're pulling data from these subreddits, add your own if you want to */
IF OBJECT_ID('tempdb..#SubredditList') IS NOT NULL DROP TABLE #SubredditList
CREATE TABLE #SubredditList (Subreddit varchar(50), Hits int)
INSERT INTO #SubredditList (Subreddit, Hits)
VALUES
 ('nosleep',0)
,('LegalAdvice',0)
,('WritingPrompts',0)
,('TalesFromTechSupport',0)
,('TalesFromRetail',0)
,('TalesFromYourServer',0)
,('thephenomenon',0)

INSERT INTO py_SubredditList (Subreddit, Hits)
SELECT t.Subreddit, t.Hits
FROM #SubredditList t
WHERE NOT EXISTS (SELECT * FROM py_SubredditList sl WHERE t.Subreddit = t.Subreddit)

/* Find the least used subreddit */
DECLARE @SubReddit varchar(50)
SET @SubReddit = (SELECT TOP 1 sr.Subreddit
					FROM py_SubredditList sr
					WHERE sr.Hits = (SELECT MIN(Hits) FROM py_SubredditList))

/* Here's our block of Python, declaring it dynamically */
DECLARE @sql nvarchar(max) = 
N'#! usr/bin/env python3
import praw
import pandas as pd
import datetime as dt

reddit = praw.Reddit(client_id=''PersonalUseScript-14Characters'', \
                     client_secret=''Secret-27Characters'', \
                     user_agent=''YourAPIName'', \
                     username=''YourRedditUsername'', \
                     password=''YourRedditPassword'')

subreddit = reddit.subreddit(''' + @SubReddit + ''')



for submission in subreddit.top(limit=1):
    print(submission.title, submission.id)

top_subreddit = subreddit.new(limit=1000)

topics_dict = { 
                "title":[],
                "score":[],
                "id":[], 
				"url":[],
                "comms_num": [],
                "created": [],
                "body":[]
            }

for submission in top_subreddit:
    topics_dict["title"].append(submission.title)
    topics_dict["score"].append(submission.score)
    topics_dict["id"].append(submission.id)
    topics_dict["url"].append(submission.url)
    topics_dict["comms_num"].append(submission.num_comments)
    topics_dict["created"].append(submission.created)
    topics_dict["body"].append(submission.selftext)

topics_data = pd.DataFrame(topics_dict)

def get_date(created):
    return dt.datetime.fromtimestamp(created)

_timestamp = topics_data["created"].apply(get_date)

topics_data = topics_data.assign(timestamp = _timestamp)

#print(topics_data.body)

OutputDataSet = topics_data
' 

IF OBJECT_ID('tempdb..#RedditData') IS NOT NULL DROP TABLE #RedditData
BEGIN
	CREATE TABLE #RedditData
	(
	 [body] varchar(max)
	,[score] varchar(max)
	,[id] varchar(max)
	,[url] varchar(max)
	,[comms_num] varchar(max)
	,[title] varchar(max)
	,[url2] varchar(max)
	,[created] varchar(max)
	)
END

INSERT INTO #RedditData 
EXEC sp_execute_external_script @language = N'Python', @script = @sql

/* Increment our subreddit list */
UPDATE py_SubredditList SET Hits = Hits + 1 WHERE Subreddit = @SubReddit

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'py_SampleData')
BEGIN
	CREATE TABLE py_SampleData
	(
	 [SampleData] varchar(max)
	,[Description] varchar(20)
	,[DataType] varchar(20)
	,[DataLen] int
	,[Subreddit] varchar(20)
	)
END

INSERT INTO py_SampleData (SampleData, Description, DataType, DataLen, Subreddit)
SELECT TRIM(title) AS SampleData, 'title' AS [Description], 'varchar' AS [DataType], LEN(title) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE title IS NOT NULL
UNION ALL
SELECT TRIM(score) AS SampleData, 'score' AS [Description], 'int' AS [DataType], LEN(score) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE score IS NOT NULL
UNION ALL
SELECT TRIM(id) AS SampleData, 'id' AS [Description], 'varchar' AS [DataType], LEN(id) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE id IS NOT NULL
UNION ALL
SELECT TRIM(url) AS SampleData, 'url' AS [Description], 'varchar' AS [DataType], LEN(url) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE url IS NOT NULL
UNION ALL
SELECT TRIM(comms_num) AS SampleData, 'comms_num' AS [Description], 'int' AS [DataType], LEN(comms_num) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE comms_num IS NOT NULL
UNION ALL
SELECT TRIM(body) AS SampleData, 'body' AS [Description], 'varchar' AS [DataType], LEN(body) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE body IS NOT NULL
UNION ALL
SELECT TRIM(url2) AS SampleData, 'url2' AS [Description], 'varchar' AS [DataType], LEN(url2) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE url2 IS NOT NULL
UNION ALL
SELECT TRIM(created) AS SampleData, 'created' AS [Description], 'datetime' AS [DataType], LEN(created) AS [DataLen], @SubReddit AS SubReddit FROM #RedditData WHERE created IS NOT NULL

SELECT * FROM #RedditData
GO


