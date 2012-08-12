class CheckGraph
	urls = 
		addChild : (parentId, childId) ->
			return "addChild.html?&graph_id=#{graphId}&parent_id=#{parentId}&child_id#{childId}"
	graphId = null
	title = null
	tasks = {}
	tasksCount = 0
	levels = []
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
			if taskStatus[id] == "Leveled"
				return
			markAs id, true
			markAs child.id, false for child in task.children
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
		initTask id for id, task of tasks
		while leveledCount < tasksCount
			markUsingTask id, task for id, task of tasks
			num = markThisLevel()
			if num == 0
				console.log "This is a cyclic graph."
				return false
			remarkTasks()
		return true
	handleGraphics = () ->
		canvasWidth = levels.length * 470
		paper = Raphael("background-canvas", "#{canvasWidth}px", "100%")
		height = 80
		width = 340
		xSpace = 130
		ySpace = 30
		xOffSet = 60
		yOffSet = ySpace
		yTextOffSet = 30
		dataContainer = $("#foreground-data")

		connectionClickStatus = 
			active: false
			taskId: null
			type: null
		addConnectionOnServer = (parentId, childId) ->
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
						paper.connection tasks[parentId].Raphael.rObj, tasks[childId].Raphael.rObj, 2, "#400"
						console.log "success"
					else
						errorHandle(response)
					console.log response
				complete:
					$(".ButtonSelected").removeClass("ButtonSelected")
				error: (response) ->
					errorHandle(response)
				})
		connectionClickHandle = (taskId, type) ->
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
						console.log "Working"
						# Ooh Awesome! Hit Server and see if everything is fine.
						addConnectionOnServer(parentId, childId)
					else
						# Remove connection
						console.log "Randi"
						tasks[parentId].children = tasks[parentId].children.slice(0, tasks[parentId].children.length - 1)
						console.log "Popped from "
						console.log tasks[parentId].children
						$(".ButtonSelected").removeClass("ButtonSelected")
				connectionClickStatus.active = false

		drawLevel = (level) ->
			yOffSet = ySpace
			# Draw Foreground Column
			column = $("<div></div>").addClass("takswrap")
			dataContainer.append column
			drawTask = (taskId) ->
				item = $("<div></div>").addClass("todo-app").addClass("red")
				item.append $("<div class='maintask'>#{tasks[taskId].title}</div>")
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
						$('<input type="submit" value="+" />')
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
						$('<input type="submit" value="+" />')
					con = $("<div class='addLinks leftlink'></div>")
					con.append leftArrow()
					con.append leftButton()
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
	isAcyclic = () ->

	constructor : (graphObj) ->
		title = graphObj.title
		initTasksObj(graphObj.tasks)
		initGraph()
