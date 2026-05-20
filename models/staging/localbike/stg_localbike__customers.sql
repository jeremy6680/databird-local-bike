with source as (

    -- Pull raw data from the localbike source dataset
    select * from {{ source('localbike', 'customers') }}

),

renamed as (

    select
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
        cast(zip_code as string) as zip_code

    from source

)

select * from renamed