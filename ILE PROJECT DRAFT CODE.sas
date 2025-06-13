


/* Step 1: Set options to display more error details for troubleshooting */
options errors=1000;

/* Step 2: Define the library location */
libname UKAdults "/home/u63753154/ILE Project";

/* Step 3: Import the CSV file using corrected configurations */
proc import datafile="/home/u63753154/ILE Project/ukr_adults_ILE.csv"
    dbms=csv 
    out=UKAdults1
    replace;
    getnames=yes;         /* Automatically capture column names */
    guessingrows=max;     /* Ensure SAS reads all rows to determine variable types */
run;

/* Step 4: Create a data step to clean up data issues, such as date formats and missing values */
data UKAdults1_clean;
    set UKAdults1;

    /* Handle date variables with appropriate formats (modify based on actual format in the CSV) */
    format Treatment_start_date yymmdd10. Treatment_end_date yymmdd10.;
    informat Treatment_start_date yymmdd10. Treatment_end_date yymmdd10.;
    
    /* Convert missing dates represented as NA or empty strings to missing values in SAS */
    if Treatment_start_date = . or Treatment_end_date = . then do;
        Treatment_start_date = .;
        Treatment_end_date = .;
    end;
    
    /* Correct any issues with character variables that may cause misalignment */
    array character_vars[*] $ _character_;
    do i = 1 to dim(character_vars);
        if character_vars[i] = 'NA' then character_vars[i] = ' ';
    end;
    drop i;

    /* Additional data cleaning based on your observations */
run;

/* Step 5: Review the summary of imported and cleaned data */
proc contents data=UKAdults1_clean; 
run;

proc print data=UKAdults1_clean(obs=10); 
run;

/*Age of the patients*/
proc means data=UKAdults1_clean min max;
    var Age;
run;

proc freq data=UKAdults1_clean;
    tables Age / nocum;
run;

proc sgplot data=UKAdults1_clean;
    histogram Age / binwidth=5 scale=count;  /* Histogram with 5-year bins */
    title "Age Distribution of Patients";

    /* Define the X-axis range for ages between 0 and 80, with ticks every 5 years */
    xaxis label="Age (Years)" values=(0 to 140 by 10) min=0 max=140;

    /* Define the Y-axis range if you expect a certain patient count range */
    yaxis label="Number of Patients" values=(1 to 20000 by 1000)min=0 max=20000;  /* Adjust max value as needed */
run;