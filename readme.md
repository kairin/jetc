```mermaid

graph TD
    subgraph Data Sources
        A[Email Notifications] -->|New Hire/Rehire| B(Workday System)
        B -->|Staff Details Report| C(External Spreadsheets)
    end

    subgraph Power Automate Flows - Data Ingestion and Conversion
        A -- Parse Email Body --> PA1[Extract Email Data]
        B -- Export & Read Report --> PA2[Process Workday Data]
        C -- Read File --> PA3[Process Spreadsheet Data]
    end

    subgraph SharePoint Lists - Centralized Storage
        PA1 --> SP1[SP List: Email New Hires]
        PA2 --> SP2[SP List: Workday Staff Data (Master)]
        PA3 --> SP3[SP List: External Staff Data]
    end

    subgraph Power Automate Flow - Data Matching and Analysis
        SP2 -- Iterate each record --> PA4[Match Data Flow]
        PA4 -- Get matching records --> SP1
        PA4 -- Get matching records --> SP3
    end

    subgraph Matching Logic
        PA4 --> D{Match Found by ID?}
        D -- Yes --> E[Data Consistent?]
        E -- Yes --> F[Log Successful Match]
        E -- No (Discrepancy) --> G[Flag Discrepancy]
        D -- No (No Match) --> H[Flag New/Unmatched Record]
    end

    subgraph Follow-up and Notifications
        G --> SP4[SP List: Pending Staff Data Review]
        H --> SP4
        SP4 -- New/Updated Item --> PA5[Send Notification]
        PA5 --> I[HR Team: Email/Teams Alert]
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#f9f,stroke:#333,stroke-width:2px
    style PA1 fill:#9cf,stroke:#333,stroke-width:2px
    style PA2 fill:#9cf,stroke:#333,stroke-width:2px
    style PA3 fill:#9cf,stroke:#333,stroke-width:2px
    style SP1 fill:#bbf,stroke:#333,stroke-width:2px
    style SP2 fill:#bbf,stroke:#333,stroke-width:2px
    style SP3 fill:#bbf,stroke:#333,stroke-width:2px
    style PA4 fill:#9cf,stroke:#333,stroke-width:2px
    style D fill:#fc9,stroke:#333,stroke-width:2px
    style E fill:#fc9,stroke:#333,stroke-width:2px
    style F fill:#afa,stroke:#333,stroke-width:2px
    style G fill:#f99,stroke:#333,stroke-width:2px
    style H fill:#f99,stroke:#333,stroke-width:2px
    style SP4 fill:#bbf,stroke:#333,stroke-width:2px
    style PA5 fill:#9cf,stroke:#333,stroke-width:2px
    style I fill:#ffc,stroke:#333,stroke-width:2px

```
