# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
  name     = var.resource_group
  location = var.reg

  tags = {
    environment = var.environment
  }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "${var.hostname}Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.reg
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  tags = {
    environment = var.environment
  }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
  name                 = "${var.hostname}Subnet"
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "${var.hostname}PublicIP"
  location            = var.reg
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  allocation_method   = "Dynamic"

  tags = {
    environment = var.environment
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "${var.hostname}NSG"
  location            = var.reg
  resource_group_name = azurerm_resource_group.myterraformgroup.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
  name                      = "${var.hostname}NIC"
  location                  = var.reg
  resource_group_name       = azurerm_resource_group.myterraformgroup.name
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id

  ip_configuration {
    name                          = "${var.hostname}NicConfiguration"
    subnet_id                     = azurerm_subnet.myterraformsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = {
    environment = var.environment
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.myterraformgroup.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.myterraformgroup.name
  location                 = var.reg
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.environment
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
  name                  = var.hostname
  location              = var.reg
  resource_group_name   = azurerm_resource_group.myterraformgroup.name
  network_interface_ids = [azurerm_network_interface.myterraformnic.id]
  vm_size               = var.vmsize

  storage_os_disk {
    name              = "${var.hostname}OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = var.hostname
    admin_username = "azureuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+zpottc4OnV25nrmTroVf4kI5yGyGtUypiMBiudMCqFaGoRX16nt9cYhJU5F8Qk8hMFzi+cPENoeIaLuhJgw0+u9eCp/IYmzQshU4pCJuBcT4sALP54Vw9hBZOZcOmTnOAUHlc/ElhCaTwfR3xoXW/6GLeYcX040X4+0PNv0fICHmGJ94otRESrW1ZgDb+r77eCu/8VgaLWbP1LApv7RRtCITpz4DiKYr0ZmzR7bCpertSjBd6OnsibIQvUB9tqYDhcisV5eMlTP1qEuJ3E+NJIJdvTcSfFxZ8lStDwKYCfmfcIl4h5dnKu+rkN1ZLxwAqRREYfmE/rMqoUnRAtyF"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }

  tags = {
    environment = var.environment
  }
}
