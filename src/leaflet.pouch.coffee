L.GeoJSON.Pouch = L.GeoJSON.extend(
	defaultParams:
		continuous: true
		direction: "from"

	initialize: (db, remoteDB, opts) ->
		if typeof remoteDB is "object"
			opts = remoteDB
			remoteDB = undefined
		@_layers = {}
		pouchParams = L.Util.extend({}, @defaultAJAXparams)
		for i of opts
			pouchParams[i] = opts[i]  if @pouchParams.hasOwnProperty(i)
		@pouchParams = pouchParams
		L.Util.setOptions @, opts
		Pouch db, (e1, db1) =>
			unless e1
				@localDB = db1
				@localDB.changes(
					continuous : @pouchParams.continuous
					include_docs : true
					onChange : (c) =>
						doc = c.doc
						if parseInt(doc._rev.slice(0, 1)) is 1
							@addData doc
						else if parseInt(doc._rev.slice(0, 1)) > 1
							@eachLayer (f) =>
								@removeLayer f  if f.feature._id is doc._id

							@addData doc  unless doc._deleted
						true			
				)
				if remoteDB
					Pouch remoteDB, (e2, db2) =>
						unless e2
							@remoteDB = db2
							options = continuous : @pouchParams.continuous
							switch @pouchParams.direction
								when "from" then @localDB.replicate.from @remoteDB, options
								when "to" then @localDB.replicate.to @remoteDB, options
								when "both"
									@localDB.replicate.from @remoteDB, options
									@localDB.replicate.to @remoteDB, options
								else console.log("you sure about that?")
										
	addDoc: (doc, cb) ->
		if "type" of doc and doc.type == "Feature"
			@localDB.post doc, cb or ()-> true unless "_id" of doc
			@localDB.put doc, cb or ()-> true if "_id" of doc
		else if "type" of doc and doc.type == "FeatureCollection"
			@localDB.bulkDocs doc.features, cb or ()-> true
		else if doc.length
			@localDB.bulkDocs doc, cb or ()-> true
		
	
	deleteDoc: (id) ->
		@localDB.get id, (err, doc) =>
			@localDB.remove doc, ()-> true unless err
		
)
L.geojson.pouch = (db, remoteDB, opts)->
	new L.GeoJSON.Pouch(db, remoteDB, opts)