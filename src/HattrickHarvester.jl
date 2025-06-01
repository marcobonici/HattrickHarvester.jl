module HattrickHarvester

using DataFrames
using Dates
using FilePathsBase: joinpath, mkpath
using Glob
using JSON
using Logging

function extract_skill(s::AbstractString, skill::String)
    """
    Extracts the level and number for a specified skill from the input string.

    ## Arguments
    - `s::AbstractString`: The input string containing player information.
    - `skill::String`: The name of the skill to extract (e.g., "Keeper", "Defending").

    ## Returns
    - `Dict{String, Any}`: A dictionary containing the "Level" and "Number" for the specified skill.
    """
    # Escape any regex special characters in the skill name
    escaped_skill = replace(skill, r"([\.\+\*\?\^\$\(\)\[\]\{\}\|\\])" => s"\\\$1")

    # Construct the regex pattern by concatenating strings
    # This ensures that the skill name is correctly inserted into the pattern
    pattern_str = "\\[th\\]" * escaped_skill * "\\[/th\\]\\[td\\](?:\\[b\\])?([^\\[\\(]+)(?:\\[/b\\])?\\s*\\((\\d+)\\)\\[/td\\]"

    # Create a Regex object from the pattern string
    pattern = Regex(pattern_str)

    # Apply the regex pattern to the input string
    m = match(pattern, s)

    if m !== nothing
        # Extract the captured groups: Level and Number
        level = strip(m.captures[1])
        number = parse(Int, m.captures[2])

        # Return the extracted information as a dictionary
        return number
    else
        # If the skill is not found, return a dictionary indicating absence
        return Dict("Level" => nothing, "Number" => nothing, "Error" => "Skill not found.")
    end
end

function extract_all_skills(s::AbstractString, skills::Vector{String})
    """
    Extracts the numerical values for a list of specified skills from the input string.

    ## Arguments
    - `s::AbstractString`: The input string containing player information.
    - `skills::Vector{String}`: A list of skill names to extract (e.g., ["Keeper", "Defending"]).

    ## Returns
    - `Dict{String, Int}`: A dictionary where each key is a skill name,
      and the value is the numerical value associated with that skill.

    ## Example
    ```julia
    input_text = "..."
    skills = ["Keeper", "Defending"]
    skill_numbers = extract_all_skills(input_text, skills)
    println(skill_numbers)  # Output: Dict("Keeper" => 1, "Defending" => 7)
    ```
    """
    # Initialize an empty dictionary to store skill numbers
    skill_numbers = Dict{String,Int}()

    # Iterate over each skill and extract its numerical value
    for skill in skills
        # Use the existing extract_skill function
        number = extract_skill(s, skill)
        # Add the skill and its number to the dictionary
        skill_numbers[skill] = number
    end

    return skill_numbers
end


function extract_tsi(s::AbstractString)
    # Define the regex pattern to capture the TSI value
    # This pattern looks for "TSI:" followed by any number of spaces and digits,
    # including non-breaking spaces (e.g., "76 670")
    pattern = r"TSI:\s*([\d\s ]+)"

    # Apply the regex pattern to the input string
    m = match(pattern, s)

    if m !== nothing
        # Extract the captured group containing the TSI number with possible spaces
        tsi_str = m.captures[1]

        # Remove all non-digit characters (including spaces and non-breaking spaces)
        tsi_num_str = replace(tsi_str, r"\D" => "")

        # Convert the cleaned string to an integer
        return parse(Int, tsi_num_str)
    else
        # If the pattern is not found, throw an error
        error("TSI information not found in the input text.")
    end
end

function extract_age(s::AbstractString)
    pattern = r"(\d+)\s+years\s+and\s+(\d+)\s+days"
    m = match(pattern, s)
    if m !== nothing
        years = parse(Int, m.captures[1])
        days = parse(Int, m.captures[2])
        return Dict("AgeYears" => years, "AgeDays" => days)
    else
        error("Age information not found in the input text.")
    end
end

function extract_speciality(s::AbstractString)
    """
    Extracts the "Speciality" value from the input string.

    ## Arguments
    - `s::AbstractString`: The input string containing player information.

    ## Returns
    - `String`: The speciality value associated with the player.

    ## Raises
    - `ArgumentError`: If "Speciality" is not found in the input string.

    ## Example
    ```julia
    input_text = "Speciality: [b]Head[/b]"
    speciality = extract_speciality(input_text)
    println(speciality)  # Output: Head
    ```
    """
    # Define the field name
    field = "Speciality"

    # Escape any regex special characters in the field name
    escaped_field = replace(field, r"([\.\+\*\?\^\$\(\)\[\]\{\}\|\\])" => s"\\\$1")

    # Construct the regex pattern to capture the value within [b] tags
    # Correct the escape sequence for '\s' by using '\\s' in the string
    pattern_str = escaped_field * ":\\s*\\[b\\](.*?)\\[/b\\]"

    # Create a Regex object from the pattern string
    pattern = Regex(pattern_str)

    # Apply the regex pattern to the input string
    m = match(pattern, s)

    if m !== nothing
        # Extract the captured group containing the speciality value
        speciality = strip(m.captures[1])
        return speciality
    else
        # If "Speciality" is not found, throw an error
        throw(ArgumentError("Speciality not found in the input text."))
    end
end

function extract_leadership(s::AbstractString)
    """
    Extracts the adjective describing 'leadership' from the input string.

    ## Arguments
    - `s::AbstractString`: The input string containing player information.

    ## Returns
    - `String`: The adjective describing leadership.

    ## Raises
    - `ArgumentError`: If 'leadership' is not found in the input string.

    ## Example
    ```julia
    input_text = "Has inadequate experience and inadequate leadership."
    leadership = extract_leadership(input_text)
    println(leadership)  # Output: inadequate
    ```
    """
    # Define the field name
    field = "leadership"

    # Escape any regex special characters in the field name
    escaped_field = replace(field, r"([\.\+\*\?\^\$\(\)\[\]\{\}\|\\])" => s"\\\$1")

    # Construct the regex pattern to capture the adjective before 'leadership'
    # Pattern Breakdown:
    # - `(?i)`: Case-insensitive matching
    # - `and\s+`: Matches 'and' followed by one or more whitespace characters
    # - `(\w+)`: Captures one or more word characters (the adjective)
    # - `\s+`: Matches one or more whitespace characters
    # - `leadership`: Matches the word 'leadership'
    pattern_str = raw"(?i)and\s+(\w+)\s+" * escaped_field

    # Create the Regex object
    pattern = Regex(pattern_str)

    # Apply the regex pattern to the input string
    m = match(pattern, s)

    if m !== nothing
        # Extract the adjective from the first capture group
        adjective = strip(m.captures[1])
        return adjective
    else
        # If 'leadership' is not found, throw an error
        throw(ArgumentError("'leadership' not found in the input text."))
    end
end

function extract_experience(s::AbstractString)
    """
    Extracts the adjective describing 'experience' from the input string.

    ## Arguments
    - `s::AbstractString`: The input string containing player information.

    ## Returns
    - `String`: The adjective describing experience.

    ## Raises
    - `ArgumentError`: If 'experience' is not found in the input string.

    ## Example
    ```julia
    input_text = "Has inadequate experience and inadequate leadership."
    experience = extract_experience(input_text)
    println(experience)  # Output: inadequate
    ```
    """
    # Define the field name
    field = "experience"

    # Escape any regex special characters in the field name
    escaped_field = replace(field, r"([\.\+\*\?\^\$\(\)\[\]\{\}\|\\])" => s"\\\$1")

    # Construct the regex pattern to capture the adjective before 'experience'
    # Pattern Breakdown:
    # - `(?i)`: Case-insensitive matching
    # - `Has\s+`: Matches 'Has' followed by one or more whitespace characters
    # - `(\w+)`: Captures one or more word characters (the adjective)
    # - `\s+`: Matches one or more whitespace characters
    # - `experience`: Matches the word 'experience'
    pattern_str = raw"(?i)Has\s+(\w+)\s+" * escaped_field

    # Create the Regex object
    pattern = Regex(pattern_str)

    # Apply the regex pattern to the input string
    m = match(pattern, s)

    if m !== nothing
        # Extract the adjective from the first capture group
        adjective = strip(m.captures[1])
        return adjective
    else
        # If 'experience' is not found, throw an error
        throw(ArgumentError("'experience' not found in the input text."))
    end
end

function get_playerid(input::String)::Union{Int,Nothing}
    """
    Extracts the playerid from the input string.

    # Arguments
    - `input::String`: The input string containing the player information.

    # Returns
    - `Int` if playerid is found.
    - `nothing` if playerid is not found.
    """
    # Define the regex pattern to match [playerid=digits]
    pattern = r"\[playerid=(\d+)\]"

    # Search for the pattern in the input string
    m = match(pattern, input)

    # If a match is found, parse and return the playerid as Int
    if m !== nothing
        return parse(Int, m.captures[1])
    else
        # Return nothing if no playerid is found
        return nothing
    end
end

function extract_player_profile(s::AbstractString)
    """
    Compiles a comprehensive player profile by extracting various attributes, including playerid.

    ## Arguments
    - `s::AbstractString`: The input string containing player information.

    ## Returns
    - `Dict{String, Any}`: A dictionary containing all extracted player attributes.

    ## Example
    ```julia
    input_text = "..."
    profile = extract_player_profile(input_text)
    println(profile)
    # Output:
    # Dict(
    #   "PlayerID" => 475716864,
    #   "Skills" => Dict("Keeper" => 1, "Defending" => 7, ...),
    #   "TSI" => 76670,
    #   "AgeYears" => 23,
    #   "AgeDays" => 67,
    #   "Speciality" => "Head",
    #   "Experience" => "inadequate",
    #   "Leadership" => "inadequate"
    # )
    ```
    """
    # Define the list of skills to extract
    skills = ["Keeper", "Defending", "Playmaking", "Passing", "Scoring", "Winger"]

    # Initialize the profile dictionary
    profile = Dict{String,Any}()

    # Extract Player ID
    try
        profile["PlayerID"] = get_playerid(s)
    catch e
        profile["PlayerID"] = nothing
        println("Error extracting PlayerID: ", e.msg)
    end

    # Extract skills
    try
        skills = extract_all_skills(s, skills)
        merge!(profile, skills)
    catch e
        profile["Skills"] = Dict{String,Any}()
        println("Error extracting skills: ", e.msg)
    end

    # Extract TSI
    try
        profile["TSI"] = extract_tsi(s)
    catch e
        profile["TSI"] = nothing
        println("Error extracting TSI: ", e.msg)
    end

    # Extract Age
    try
        age_info = extract_age(s)
        profile["AgeYears"] = age_info["AgeYears"]
        profile["AgeDays"] = age_info["AgeDays"]
    catch e
        profile["AgeYears"] = nothing
        profile["AgeDays"] = nothing
        println("Error extracting Age: ", e.msg)
    end

    # Extract Speciality
    try
        profile["Speciality"] = extract_speciality(s)
    catch e
        profile["Speciality"] = "None"
        println("Error extracting Speciality: ", e.msg)
    end

    # Extract Experience and Leadership
    try
        profile["Experience"] = extract_experience(s)
    catch e
        profile["Experience"] = nothing
        println("Error extracting Experience: ", e.msg)
    end

    try
        profile["Leadership"] = extract_leadership(s)
    catch e
        profile["Leadership"] = nothing
        println("Error extracting Leadership: ", e.msg)
    end

    return profile
end

function save_dict_to_json(dict::Dict{String,Any}, pippo::String)
    # Validate that pippo is not empty
    if isempty(pippo)
        throw(ArgumentError("The filename base 'pippo' cannot be empty."))
    end
    # Optional: Validate that `pippo` does not contain invalid filename characters
    # (This step can be customized based on the operating system)
    # For simplicity, we'll assume `pippo` is a valid filename

    # Construct the full filename by appending ".json"
    filename = "$(pippo).json"

    try
        # Serialize the dictionary to a pretty JSON string with indentation
        json_string = JSON.json(dict, 4)  # 4 spaces indentation for readability

        # Write the JSON string to the file
        open(filename, "w") do io
            write(io, json_string)
        end

        println("Dictionary successfully saved to \"$(filename)\".")
    catch e
        # Handle any I/O errors
        throw(IOError("Failed to write to file \"$(filename)\": $(e.message)"))
    end
end

function save_player_profile(profile::Dict, root)
    save_dict_to_json(profile, root * string(profile["PlayerID"]))
    return nothing
end

function save_player_profile(s::AbstractString, root::AbstractString)
    profile = extract_player_profile(s)
    save_player_profile(profile::Dict, root)
    return nothing
end

function load_json(filename::String)::Dict{String,Any}
    """
    Loads a JSON file and returns its contents as a dictionary.

    # Arguments
    - `filename::String`: The path to the JSON file (e.g., "pippo.json").

    # Returns
    - `Dict{String, Any}`: A dictionary containing the parsed JSON data.

    # Example
    ```julia
    data = load_json("pippo.json")
    println(data)
    ```
    """
    try
        # Read and parse the JSON file
        return JSON.parsefile(filename)
    catch e
        throw(IOError("Failed to load JSON file \"$(filename)\": $(e.message)"))
    end
end

function custom_calendar_date(standard_date::Date)
    # Define the base date and its corresponding custom calendar position
    base_date = Date(2024, 11, 16)  # 16-11-2024
    base_week = 9  # 9th week
    base_day_of_week = 7  # 7th day of the week
    base_year = 89  # 89th custom year

    # Custom calendar parameters
    days_in_week = 7
    weeks_in_year = 16
    days_in_year = days_in_week * weeks_in_year  # 112 days in a custom year

    # Calculate the difference in days from the base date
    day_difference = standard_date - base_date
    total_days = Dates.value(day_difference)  # Convert the period to an integer

    # Calculate the position in the custom calendar
    base_position = (base_week - 1) * days_in_week + base_day_of_week
    current_position = base_position + total_days

    # Determine the custom year and week
    custom_year_offset = div(current_position - 1, days_in_year)
    custom_year = base_year + custom_year_offset
    custom_day_of_year = mod(current_position - 1, days_in_year) + 1
    custom_week = div(custom_day_of_year - 1, days_in_week) + 1

    return custom_year, custom_week
end

"""
    extract_last_numbers(text::String) -> Dict{String, Int}

Given an input string containing, somewhere in order:

1. A “Season” token (all digits), immediately followed by a “(SeasonWeek)” token.
2. One or more tokens that together form “TSI” (digits possibly split across tokens).
3. An “AgeYears” token (all digits) immediately followed by an “(AgeDays)” token.
4. One or more tokens that together form “Price”, ending with a token containing “€” (e.g. “5”, “100”, “000”, “€”).

This function:
- Finds the first instance of “Season (SeasonWeek)”.
- Collects all tokens after that (up until the next “Digits (Digits)” pair) as TSI.
- Parses AgeYears and AgeDays.
- Gathers price tokens until it sees “€” and strips out non-digits.
Returns a Dict with keys:
  "Season", "SeasonWeek", "TSI", "AgeYears", "AgeDays", "Price"
Each mapped to an Int.

If parsing fails at any step, it throws an error indicating which part didn’t match.
"""
function extract_last_numbers(text::String)
    tokens = split(text)           # split on any whitespace
    n = length(tokens)

    # 1) Locate Season and SeasonWeek: find i where tokens[i] is all digits and tokens[i+1] is "(digits)"
    season = nothing
    season_week = nothing
    season_idx = 0
    for i in 1:(n-1)
        if occursin(r"^\d+$", tokens[i]) && occursin(r"^\(\d+\)$", tokens[i+1])
            season = parse(Int, tokens[i])
            season_week = parse(Int, strip(tokens[i+1], ['(', ')']))
            season_idx = i
            break
        end
    end

    if season === nothing
        error("Could not locate a `Season (SeasonWeek)` pattern in the input.")
    end

    # 2) Identify where AgeYears and AgeDays occur. That is the first k > season_idx+1 such that:
    #      tokens[k] ~ "^\d+$"  AND  tokens[k+1] ~ "^\(\d+\)$"
    #    Everything between season_idx+2 and k-1 (inclusive) belongs to TSI.
    j = season_idx + 2
    if j > n
        error("No tokens after `Season (SeasonWeek)` for TSI/Age fields.")
    end

    age_years = nothing
    age_days = nothing
    age_idx = 0

    for k in (j+1):(n-1)
        if occursin(r"^\d+$", tokens[k]) && occursin(r"^\(\d+\)$", tokens[k+1])
            age_years = parse(Int, tokens[k])
            age_days = parse(Int, strip(tokens[k+1], ['(', ')']))
            age_idx = k
            break
        end
    end

    if age_years === nothing
        error("Could not locate `AgeYears (AgeDays)` after TSI tokens.")
    end

    # 3) Parse TSI: tokens[j .. age_idx-1]
    if age_idx - 1 < j
        error("TSI tokens missing (no tokens between SeasonWeek and AgeYears).")
    end
    tsi_digits = ""
    for t in tokens[j:(age_idx-1)]
        # remove any nondigit characters, then concatenate
        digits = replace(t, r"\D" => "")
        tsi_digits *= digits
    end
    if isempty(tsi_digits)
        error("Could not parse TSI from tokens: $(tokens[j:(age_idx - 1)])")
    end
    tsi = parse(Int, tsi_digits)

    # 4) Parse Price: start at tokens[age_idx+2], accumulate digits until a token containing "€" appears.
    price_idx = age_idx + 2
    if price_idx > n
        error("No tokens after `AgeYears (AgeDays)` to parse Price.")
    end

    price_digits = ""
    found_euro = false
    while price_idx <= n
        tok = tokens[price_idx]
        if occursin("€", tok)
            # Strip nondigits and append what's left
            digits_part = replace(tok, r"[^\d]" => "")
            price_digits *= digits_part
            found_euro = true
            break
        else
            # Append any digits in this token
            digits_part = replace(tok, r"\D" => "")
            price_digits *= digits_part
        end
        price_idx += 1
    end

    if !found_euro || isempty(price_digits)
        error("Could not parse Price (no “€” found or no digits) from trailing tokens.")
    end
    price = parse(Int, price_digits)

    return Dict(
        "Season" => season,
        "SeasonWeek" => season_week,
        "TSI" => tsi,
        "AgeYears" => age_years,
        "AgeDays" => age_days,
        "Price" => price
    )
end

function for_loop(input_folder, output_folder)
    keys_to_drop = Set(["TSI", "AgeDays", "AgeYears"])

    for in_path in glob("*.json", input_folder)
        println("────────────────────────────────────")
        println("Processing: ", in_path)

        try
            # 1) Load first dict
            content = JSON.parsefile(in_path)  # Dict{String,Any}

            # 2) Print and check PlayerID
            println("Original JSON:")
            println(content)
            if !haskey(content, "PlayerID")
                @warn "Missing PlayerID" file = in_path
                continue
            end
            player_id = content["PlayerID"]
            @info "Player ID being analyzed" player_id

            # 3) Collect multiline input
            println("\nPaste your data block (end with blank line):")
            lines = String[]
            while true
                line = readline()
                isempty(line) && break
                push!(lines, line)
            end
            user_block = join(lines, "\n")

            # 4) Harvest second dict
            second_dict = HattrickHarvester.extract_last_numbers(user_block)
            println("\nExtracted dict:")
            println(second_dict)

            # 5) Filter out unwanted keys from first dict
            first_filtered = Dict{String,Any}()
            for (k, v) in content
                k in keys_to_drop || (first_filtered[k] = v)
            end

            # 6) Merge dicts
            merged = merge(first_filtered, second_dict)
            println("\nMerged dict:")
            println(merged)

            # 7) Build output filename: playerID_season_seasonWeek.json
            #    Adjust the key names below to match your second_dict:
            season = get(merged, "Season", get(merged, "season", missing))
            seasonweek = get(merged, "SeasonWeek", get(merged, "seasonWeek", missing))

            if season === missing || seasonweek === missing
                @warn "Missing season or seasonWeek in merged dict; using generic filename"
                filename = "$(player_id)"
            else
                filename = string(player_id, "_", season, "_", seasonweek)
            end

            # 8) Write to output folder
            out_path = joinpath(output_folder, filename)
            save_dict_to_json(merged, out_path)
            println("→ Written: ", out_path)

        catch err
            @error "Error processing file" file = in_path error = err
        end

        println()  # spacer
    end
    return nothing
end

end # module HattrickHarvester
