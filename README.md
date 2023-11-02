Usage: ruby challenge.rb [options]
--users_file USERSFILE
--companies_file COMPANIESFILE

Ensure you have the required gems (i.e. bundle install or gem install json-schema)

The program processes a json file of users, and a json file of companies.
The files must match the schemas provided below (USERS_SCHEMA & COMPANIES_SCHEMA) to be processed.
It creates an output file (output.txt) in the directory it's run from.
The output file outputs a list of companies (id & name) and the total amount of tokens topped up
It includes a list of whether the users should be e-mailed or not
The lists include the user name, e-mail and their balance pre and post top-up

Recommendations & assumptions

- Challenge doesn't mention the "Total amount of top ups", but it's in the output so I included it
- The total amount of top ups line was indented to line up with "Users Not Emailed:" rather than under the company
  itself.
  I've lined it up with the company itself as the total is for all users, not just those emailed.
- The output format in the sample output for "Previous token balance" has a comma after it,
  whereas "New Token Balance" does not, I've made these consistent in my output
- The sample output has the header for "Users Emailed:" output even when there are no users, so I included it too.
  It might be worth hiding this or changing it to something different if the list is empty (same applies for no users
  e-mailed being empty)
  Future thoughts
- Implement tests
- Allow output file as a param
- Pull users/companies to their own classes instead of working with hashes
- Implement e-mailing
