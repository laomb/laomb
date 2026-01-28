
macro struct? name*

	macro end?.struct?!
			end namespace
		esc end struc

		virtual at 0
			name name
			sizeof.name = $
		end virtual

		purge end?.struct?
	end macro

	esc struc name
		label . : sizeof.name
		namespace .
end macro
