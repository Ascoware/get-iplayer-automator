-- GetOperaURL.applescript
-- Get_iPlayer GUI

--  Created by Thomas Willson on 8/7/09.
--  Copyright 2009 __MyCompanyName__. All rights reserved.
try
	tell application "System Events"
		set isRunning to ((application processes whose (name is equal to "Opera")) count)
	end tell
	if isRunning is greater than 0 then
		tell application "Opera"
			set myInfo to GetWindowInfo of window 1
			set myURL to item 1 of myInfo
		end tell
	else
		set myURL to "Error"
	end if
on error
	set myURL to "Error"
end try
return myURL as string