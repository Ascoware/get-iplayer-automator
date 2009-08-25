-- GetFireFoxURL.applescript
-- Get_iPlayer GUI

--  Created by Thomas Willson on 8/7/09.
--  Copyright 2009 __MyCompanyName__. All rights reserved.
try
	tell application "System Events"
		set isRunning to ((application processes whose (name is equal to "Firefox")) count)
	end tell
	if isRunning is greater than 0 then
		tell application "Firefox"
			set myURL to «class curl» of window 1
		end tell
	else
		set myURL to "Error"
	end if
on error
	set myURL to "Error"
end try
return myURL as string
