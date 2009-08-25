-- GetCaminoURL.applescript
-- Get_iPlayer GUI

--  Created by Thomas Willson on 8/7/09.
--  Copyright 2009 __MyCompanyName__. All rights reserved.
try
	tell application "System Events"
		set isRunning to ((application processes whose (name is equal to "Camino")) count)
	end tell
	if isRunning is greater than 0 then
		tell application "Camino"
			tell browser window 1
				set myURL to URL of current tab
			end tell
		end tell
	else
		set myURL to "Error"
	end if
on error
	set myURL to "Error"
end try
return myURL as string