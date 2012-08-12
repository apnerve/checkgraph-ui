class CheckGraph
	urls = 
		addChild : (parentId, childId) ->
			return "addChild.html?&graph_id=#{graphId}&parent_id=#{parentId}&child_id#{childId}"
		changeStatus : (taskId, status) ->
			return "changeStatus.php?&graph_id=#{graphId}&task_id=#{taskId}&status=#{status}"
		createTask : (name) ->
			return "createTask.php?graph_id=#{graphId}&name=" + encodeURIComponent(name);
	graphId = null
	title = null
	tasks = {}
	tasksCount = 0
	levels = []

	addConnectionOnServer = (parentId, childId, drawer) ->
		errorHandle = (response) ->
				console.log "Error"
				console.log response
				tasks[parentId].children = tasks[parentId].children.slice(0, tasks[parentId].children.length - 1)
		$.ajax({
			url: urls.addChild(parentId, childId)
			# type: 'json'
			method: 'get'
			success: (response) ->
				if response.status == 200 or true
					if drawer?
						drawer(parentId, childId)
					console.log "success"
					tasksCleanup()
					populateLevels()
					handleGraphics(true)
				else
					errorHandle(response)
				console.log response
			complete:
				$(".ButtonSelected").removeClass("ButtonSelected")
			error: (response) ->
				errorHandle(response)
			})

	# Add a new task
	tasksCleanup = () ->
		cleanup = (taskId) ->
			tasks[taskId].DOMItem = null
			tasks[taskId].Raphael = null
			tasks[taskId].isOpen = null
		cleanup id for id, task in tasks
	addNewTask = (connectedTo, isChild) ->
		$("#myModal h1").html("Add a new Task")
		$("#myModal input[type=submit]").off()
		$("#myModal input[type=submit]").click((event)->
			event.preventDefault()
			name = $("#myModal input[type=text]").val()
			url = urls.createTask(name)
			$.get(url).success((response) ->
				tasks[response.task.id] = response.task
				console.log "Here"
				if connectedTo?
					if isChild
						tasks[connectedTo].children.push {id:response.task.id}
						addConnectionOnServer connectedTo, response.task.id
					else
						tasks[response.task.id].children.push {id:connectedTo}
						addConnectionOnServer response.task.id, connectedTo
				tasksCount += 1
				tasksCleanup()
				populateLevels()
				handleGraphics(true)
			).error((response) ->
				console.log "Unable to create Task"
			).complete(() ->
				$("#myModal").trigger('reveal:close')
			)
		)	
		$("#myModal").reveal()
	handleClass = (obj, isDone, isOpen) ->
		h = (add, remove) ->
			obj.addClass cls for cls in add
			obj.removeClass cls for cls in remove
		if isDone
			h ["done-task", "blue"], ["open-task", "red", "yellow"]
		else if isOpen
			h ["open-task", "red"], ["done-task", "blue", "yellow"]
		else
			h ["yellow"], ["open-task", "done-task", "blue", "red"]
	# Marks Task As
	markTaskAs = (taskId, newStatus) ->
		checkIfOpen = (taskId) ->
			isOpen = true
			shouldMarkFalse = (parentId, parent) ->
				isParent = false
				markParent = (childId) ->
					if String(childId) == String(taskId)
						isParent = true
				markParent child.id for child in parent.children
				if isParent and tasks[parentId].status != "DONE"
					isOpen = false
			shouldMarkFalse id, task for id, task of tasks
			if isOpen and !tasks[taskId].isOpen
				tasks[taskId].isOpen = true
				handleClass(tasks[taskId].DOMItem, false, true)

		markTaskAsDone = () ->
			$.ajax({
				url: urls.changeStatus(taskId, "DONE")
				method: "GET"
				success: (response) ->
					console.log "Marked Done"
					tasks[taskId].status = "DONE"
					handleClass(tasks[taskId].DOMItem, true, true)
					checkIfOpen child.id for child in tasks[taskId].children
				error: (response) ->
					console.log "Unable to Mark Done"
				complete: (response) ->
					console.log "Completed"
			})
		oldStatus = tasks[taskId].status
		if oldStatus != newStatus
			if oldStatus == "NOT_DONE" and tasks[taskId].isOpen and newStatus == "DONE"
				markTaskAsDone()

	# Creates a id indexed task object.
	initTasksObj = (taskList) ->
		tasksCount = taskList.length
		addTask = (task) ->
			tasks[task.id] = task
		addTask task for task in taskList

	# Populates Levels
	populateLevels = () ->
		taskStatus = {}
		isLeveled = {}
		levels = []

		leveledCount = 0
		markUsingTask = (id, task) ->
			markAs = (task_id, isParent) ->
				if !taskStatus[task_id]?
					taskStatus[task_id] = if isParent then "Parent" else "Child"
				else if taskStatus[task_id] == "Parent" and isParent == false
					taskStatus[task_id] = "Child"
			lockTask = (task_id) ->
				tasks[task_id].isOpen = false
			if taskStatus[id] == "Leveled"
				return
			markAs id, true
			markAs child.id, false for child in task.children
			if task.status == "NOT_DONE"
				lockTask child.id for child in task.children
		remarkTasks = () ->
			remark = (id) ->
				if taskStatus[id] != "Leveled" 
					taskStatus[id] = "Parent" 
			remark id for id, task of taskStatus
		markThisLevel = () ->
			thisLevel = []
			handleTaskLeveling = (task_id, status) ->
				if status == "Parent"
					thisLevel.push task_id
					taskStatus[task_id] = "Leveled"
			handleTaskLeveling id,status for id, status of taskStatus
			levels.push thisLevel
			leveledCount = leveledCount + thisLevel.length
			return thisLevel.length

		initTask = (id) ->
			isLeveled[id] = false
			tasks[id].isOpen = true
		initTask id for id, task of tasks
		while leveledCount < tasksCount
			markUsingTask id, task for id, task of tasks
			num = markThisLevel()
			if num == 0
				console.log "This is a cyclic graph."
				return false
			remarkTasks()
		return true
	handleGraphics = (cleanup) ->
		if cleanup? and cleanup == true
			$("#background-canvas").empty()
			$("#foreground-data").empty()
		canvasWidth = levels.length * 470
		addFloatingPlus()
		paper = Raphael("background-canvas", "#{canvasWidth}px", "100%")
		height = 105
		width = 335
		xSpace = 135
		ySpace = 33
		xOffSet = 65
		yOffSet = ySpace + 2
		yTextOffSet = 30
		dataContainer = $("#foreground-data")

		connectionDrawer = (parent, child) ->
			paper.connection tasks[parent].Raphael.rObj, tasks[child].Raphael.rObj, 2, "#400"
		connectionClickStatus = 
			active: false
			taskId: null
			type: null
		connectionClickHandle = (taskId, type, drawer) ->
			if !connectionClickStatus.active
				connectionClickStatus.active = true
				connectionClickStatus.taskId = taskId
				connectionClickStatus.type = type
			else
				# Was Active.
				if connectionClickStatus.type == type
					console.log "Same Type! Couldn't connect"
				else if connectionClickStatus.taskId == taskId
					console.log "Same Task! Couldn't connect"
				else
					parentId = if type == "right" then taskId else connectionClickStatus.taskId
					childId = if type == "left" then taskId else connectionClickStatus.taskId
					# Try connection and see if still Acyclic
					newChildRef = {
						id: childId
					}
					tasks[parentId].children.push newChildRef

					if populateLevels()
						# Ooh Awesome! Hit Server and see if everything is fine.
						addConnectionOnServer(parentId, childId, connectionDrawer)
					else
						# Remove connection
						tasks[parentId].children = tasks[parentId].children.slice(0, tasks[parentId].children.length - 1)
						$(".ButtonSelected").removeClass("ButtonSelected")
				connectionClickStatus.active = false

		drawLevel = (level) ->
			yOffSet = ySpace
			# Draw Foreground Column
			column = $("<div></div>").addClass("takswrap")
			dataContainer.append column
			drawTask = (taskId) ->
				item = $("<div></div>").addClass("todo-app")
				item.append $("<div class='maintask'>#{tasks[taskId].name}</div>")
				tasks[taskId].DOMItem = item
				handleClass(item, tasks[taskId].status == "DONE", tasks[taskId].isOpen)
				doneLink = () ->
					con = $("<div></div>").addClass "actions"
					doneButton = () ->
						but = $("<input type='submit' value='Done'>");
						but.click(->
							markTaskAs taskId, "DONE"
						)
					con.append doneButton()
					return con
				
				rightLinks = () ->
					con = $("<div class='addLinks'></div>")
					rightArrow = () ->
						ele = $('<input type="submit" value=">" />')
						ele.click(->
							ele.addClass "ButtonSelected"
							connectionClickHandle(taskId, "right")
						)
						return ele
					rightButton = () ->
						ele = $('<input type="submit" value="+" />')
						ele.click(->
							addNewTask taskId, true
						)
						return ele
					con.append rightArrow()
					con.append rightButton()
					return con
				leftLinks = () ->
					leftArrow = () ->
						ele = $('<input type="submit" value="<" />')
						ele.click(->
							ele.addClass "ButtonSelected"
							connectionClickHandle(taskId, "left")
						)
						return ele
					leftButton = () ->
						ele = $('<input type="submit" value="+" />')
						ele.click(->
							addNewTask taskId, false
						)
						return ele
					con = $("<div class='addLinks leftlink'></div>")
					con.append leftArrow()
					con.append leftButton()
				item.append doneLink()
				item.append rightLinks()
				item.append leftLinks()
				tasks[taskId].Raphael =
					rObj : paper.rect(xOffSet, yOffSet, width, height)
					taskDataItem: item
				yOffSet = yOffSet + height + ySpace
				column.append item
			drawTask taskId for taskId in level
			xOffSet = xOffSet + width + xSpace
		addChildConnection = (id, task) ->
			addConnection = (obj1, obj2) ->
				paper.connection obj1, obj2, 2, "#400"

			addConnection task.Raphael.rObj, tasks[child.id].Raphael.rObj for child in task.children
		# paper.setViewBox 0, 0, xOffSet, yOffSet, true
		drawLevel level for level in levels
		addChildConnection id, task for id, task of tasks 
	initGraph = () ->
		populateLevels()
		window.onload = -> 
			handleGraphics()
		# Find the roots.
	addFloatingPlus = () ->
		plus = $("<div>+</div>")
		plus.addClass("FloatingPlus")
		plus.click(->
			addNewTask()
		)
		$("#foreground-data").prepend plus
	constructor : (graphObj) ->
		title = graphObj.title
		initTasksObj(graphObj.tasks)
		initGraph()
