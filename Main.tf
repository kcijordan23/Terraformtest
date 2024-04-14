# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}


// Create a resource group

resource "azurerm_resource_group" "hash-rg" {
  name     = "hashicorp-rg"
  location = "uk south"
  tags = {
    environment = "dev"

  }
}


// Create a virtual network

resource "azurerm_virtual_network" "has-vn" {
  name                = "hash-vnet"
  resource_group_name = azurerm_resource_group.hash-rg.name
  location            = azurerm_resource_group.hash-rg.location
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "dev"
  }
}


// Create a subnet configuration

resource "azurerm_subnet" "has-subnet" {
  name                 = "hash_internal"
  resource_group_name  = azurerm_resource_group.hash-rg.name
  virtual_network_name = azurerm_virtual_network.has-vn.name
  address_prefixes     = ["10.0.1.0/24"]
}

// Create NSG

resource "azurerm_network_security_group" "hash-nsg" {
  name                = "hash-nsg"
  location            = azurerm_resource_group.hash-rg.location
  resource_group_name = azurerm_resource_group.hash-rg.name


  tags = {
    environment = "dev"
  }

}


// Create NSG rule

resource "azurerm_network_security_rule" "hash-nsg-rule" {
  name                        = "Hash-NSG-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hash-rg.name
  network_security_group_name = azurerm_network_security_group.hash-nsg.name
}


// Associate the NSG with the subnet

resource "azurerm_subnet_network_security_group_association" "Hash-NSG-assoc" {
  subnet_id                 = azurerm_subnet.has-subnet.id
  network_security_group_id = azurerm_network_security_group.hash-nsg.id

}

// Create a public IP address

resource "azurerm_public_ip" "hash-ip" {
  name                = "hash-ip"
  location            = azurerm_resource_group.hash-rg.location
  resource_group_name = azurerm_resource_group.hash-rg.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}


// Create a network interface

resource "azurerm_network_interface" "hash-nic" {
  name                = "hash-nic"
  location            = azurerm_resource_group.hash-rg.location
  resource_group_name = azurerm_resource_group.hash-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.has-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hash-ip.id
  }

  tags = {
    environment = "dev"
  }

}


// Create a virtual machine

resource "azurerm_linux_virtual_machine" "hash-vm" {
  name                  = "hash-vm"
  location              = azurerm_resource_group.hash-rg.location
  resource_group_name   = azurerm_resource_group.hash-rg.name
  network_interface_ids = [azurerm_network_interface.hash-nic.id]
  size                  = "standard_b1s"
  admin_username        = "adminuser"

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/hash-key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/hash-key"
    })
    interpreter = var.host_os == "windows"? ["Powershell", "-Command"] : ["/bin/bash", "-c"]  
  }


  tags = {
    environment = "dev"

  }
}

data "azurerm_public_ip" "hash-ip-data" {
  name                = azurerm_public_ip.hash-ip.name
  resource_group_name = azurerm_resource_group.hash-rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.hash-vm.name}: ${data.azurerm_public_ip.hash-ip-data.ip_address}"
}
