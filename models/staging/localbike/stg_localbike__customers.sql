WITH source AS (

    -- Pull raw data from the localbike source dataset
    SELECT * FROM {{ source('localbike', 'customers') }}

),

renamed AS (

    SELECT
        -- Primary key
        customer_id,

        -- Customer name
        first_name,
        last_name,

        -- Contact details
        phone,
        email,

        -- Address
        street,
        city,
        state,

        -- Cast zip_code to STRING — it's an integer in the source but
        -- should be treated as a code, not a number (no arithmetic on it)
        CAST(zip_code AS STRING) AS zip_code

    FROM source

)

SELECT * FROM renamed
